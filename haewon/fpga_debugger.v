module fpga_debugger(
    input clk,              // 100MHz 보드 클럭
    input rstn,             // Active-low 리셋
    input sw_mode,          // SW0: 0=UART 모드(25MHz), 1=Debug 모드(3Hz)
    input uart_rx,          // UART RX
    output uart_tx,         // UART TX
    output [6:0] seg,       // 7-segment 세그먼트
    output [7:0] anode,     // 7-segment 애노드 (8자리)
    output [1:0] led        // LED[0]=RX, LED[1]=TX
);

wire rst;
assign rst = ~rstn;

// =============================================================================
// 클럭 분주기
// =============================================================================
reg [25:0] div;
always @(posedge clk or posedge rst) begin
    if (rst) div <= 0;
    else     div <= div + 1;
end

// CPU 클럭 선택: sw_mode=0 → 25MHz, sw_mode=1 → ~3Hz (디버그)
wire cpu_clk;
assign cpu_clk = sw_mode ? div[24] : div[1];

// =============================================================================
// UART 신호 (100MHz 도메인)
// =============================================================================
wire [7:0] uart_rx_data;
wire uart_rx_valid;
wire uart_tx_busy;

// =============================================================================
// CPU ↔ UART 인터페이스 신호
// =============================================================================
wire [7:0] tx_data_cpu;
wire tx_we_cpu;
wire rx_re_cpu;

// =============================================================================
// CDC: CPU → UART (cpu_clk → 100MHz)
// =============================================================================
reg [2:0] tx_we_sync;
always @(posedge clk or posedge rst) begin
    if (rst) tx_we_sync <= 3'b000;
    else     tx_we_sync <= {tx_we_sync[1:0], tx_we_cpu};
end
wire tx_we_pulse = tx_we_sync[1] & ~tx_we_sync[2];

reg [2:0] rx_re_sync;
always @(posedge clk or posedge rst) begin
    if (rst) rx_re_sync <= 3'b000;
    else     rx_re_sync <= {rx_re_sync[1:0], rx_re_cpu};
end
wire rx_re_pulse = rx_re_sync[1] & ~rx_re_sync[2];

reg [7:0] tx_data_latched;
always @(posedge clk or posedge rst) begin
    if (rst) tx_data_latched <= 8'h00;
    else if (tx_we_pulse) tx_data_latched <= tx_data_cpu;
end

// =============================================================================
// CDC: UART → CPU (100MHz → cpu_clk)
// =============================================================================
reg [1:0] rx_valid_sync;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) rx_valid_sync <= 2'b00;
    else     rx_valid_sync <= {rx_valid_sync[0], uart_rx_valid};
end
wire cpu_rx_valid = rx_valid_sync[1];

reg [1:0] tx_busy_sync;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) tx_busy_sync <= 2'b00;
    else     tx_busy_sync <= {tx_busy_sync[0], uart_tx_busy};
end
wire cpu_tx_busy = tx_busy_sync[1];

reg [7:0] rx_data_sync1, rx_data_sync2;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) begin
        rx_data_sync1 <= 8'h00;
        rx_data_sync2 <= 8'h00;
    end else begin
        rx_data_sync1 <= uart_rx_data;
        rx_data_sync2 <= rx_data_sync1;
    end
end
wire [7:0] cpu_rx_data = rx_data_sync2;

// =============================================================================
// 입력 숫자 누적 로직 (100MHz 도메인에서 처리)
// Enter 누를 때까지 입력 숫자 누적, Enter 시 display_number 업데이트
// =============================================================================
reg [31:0] input_buffer;     // 입력 중인 숫자
reg [31:0] display_number;   // Enter 후 표시할 숫자
reg rx_valid_prev;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        input_buffer <= 32'd0;
        display_number <= 32'd0;
        rx_valid_prev <= 1'b0;
    end else begin
        rx_valid_prev <= uart_rx_valid;
        
        // Rising edge of rx_valid (새 데이터 수신)
        if (uart_rx_valid && !rx_valid_prev) begin
            // 숫자 '0'-'9' (ASCII 0x30-0x39)
            if (uart_rx_data >= 8'h30 && uart_rx_data <= 8'h39) begin
                // 숫자 누적 (최대 99999999)
                if (input_buffer <= 32'd9999999)
                    input_buffer <= input_buffer * 10 + (uart_rx_data - 8'h30);
            end
            // Enter (CR=0x0D) 또는 Newline (LF=0x0A)
            else if (uart_rx_data == 8'h0D || uart_rx_data == 8'h0A) begin
                display_number <= input_buffer;  // 표시 업데이트
                input_buffer <= 32'd0;           // 버퍼 리셋
            end
            // Backspace (0x08) 또는 Delete (0x7F)
            else if (uart_rx_data == 8'h08 || uart_rx_data == 8'h7F) begin
                input_buffer <= input_buffer / 10;  // 마지막 자릿수 삭제
            end
        end
    end
end

// =============================================================================
// DATA PATH (CPU)
// =============================================================================
wire [31:0] PC;
wire [31:0] inst_out;
wire forwarding_active, hazard_stall;
wire [31:0] PC_inc, PC_gen_out, PC_in;
wire [31:0] data_read_1, data_read_2, write_data, imm_out, alu_mux, alu_out, data_mem_out;

data_path dp(
    .clk(cpu_clk),
    .rst(rst),
    .inst_out_ext(inst_out),
    .branch_ext(),
    .mem_read_ext(),
    .mem_to_reg_ext(),
    .mem_write_ext(),
    .alu_src_ext(),
    .reg_write_ext(),
    .alu_op_ext(),
    .z_flag_ext(),
    .alu_ctrl_out_ext(),
    .PC_inc_ext(PC_inc),
    .pc_gen_out_ext(PC_gen_out),
    .PC_ext(PC),
    .PC_in_ext(PC_in),
    .data_read_1_ext(data_read_1),
    .data_read_2_ext(data_read_2),
    .write_data_ext(write_data),
    .imm_out_ext(imm_out),
    .shift_ext(),
    .alu_mux_ext(alu_mux),
    .alu_out_ext(alu_out),
    .data_mem_out_ext(data_mem_out),
    .led_reg_out(),

    .uart_tx_data_out(tx_data_cpu),
    .uart_tx_we_out(tx_we_cpu),
    .uart_rx_re_out(rx_re_cpu),
    .uart_rx_data_in(cpu_rx_data),
    .uart_rx_valid_in(cpu_rx_valid),
    .uart_tx_busy_in(cpu_tx_busy),

    .forwarding_active_ext(forwarding_active),
    .hazard_stall_ext(hazard_stall)
);

// =============================================================================
// UART (100MHz)
// =============================================================================
uart u_uart (
    .clk(clk),
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd868),          // 100MHz / 868 ≈ 115200 baud
    .reg_dat_di(tx_data_latched),
    .reg_dat_do(uart_rx_data),
    .reg_dat_we(tx_we_pulse),
    .reg_dat_re(rx_re_pulse),
    .tx_busy(uart_tx_busy),
    .rx_valid(uart_rx_valid)
);

// =============================================================================
// LED
// =============================================================================
assign led[0] = uart_rx_valid;
assign led[1] = uart_tx_busy;

// =============================================================================
// 7-Segment 디스플레이 (8자리)
// Debug 모드: PC 값 (hex)
// UART 모드: 입력한 숫자 (decimal) - Enter 후 업데이트
// =============================================================================
reg [31:0] seg_value;

always @(*) begin
    if (sw_mode)
        seg_value = PC;              // Debug 모드: PC 값 (hex)
    else
        seg_value = display_number;  // UART 모드: Enter 후 숫자
end

// 8자리 7-segment 드라이버
eight_digit_seven_segment_driver seg_driver (
    .clk(clk),
    .rst(rst),
    .num(seg_value),
    .anode(anode),
    .seg(seg)
);

endmodule

// =============================================================================
// 8자리 7-Segment 드라이버 (Decimal 표시)
// =============================================================================
module eight_digit_seven_segment_driver (
    input clk,
    input rst,
    input [31:0] num,
    output reg [7:0] anode,
    output reg [6:0] seg
);

// 각 자릿수 (10진수)
wire [3:0] digit0 = num % 10;
wire [3:0] digit1 = (num / 10) % 10;
wire [3:0] digit2 = (num / 100) % 10;
wire [3:0] digit3 = (num / 1000) % 10;
wire [3:0] digit4 = (num / 10000) % 10;
wire [3:0] digit5 = (num / 100000) % 10;
wire [3:0] digit6 = (num / 1000000) % 10;
wire [3:0] digit7 = (num / 10000000) % 10;

// 스캔 카운터 (약 1kHz 스캔 속도)
reg [16:0] scan_counter;
wire [2:0] scan_digit = scan_counter[16:14];

always @(posedge clk or posedge rst) begin
    if (rst) scan_counter <= 0;
    else     scan_counter <= scan_counter + 1;
end

// 현재 표시할 자릿수 선택
reg [3:0] current_digit;
always @(*) begin
    case (scan_digit)
        3'd0: current_digit = digit0;
        3'd1: current_digit = digit1;
        3'd2: current_digit = digit2;
        3'd3: current_digit = digit3;
        3'd4: current_digit = digit4;
        3'd5: current_digit = digit5;
        3'd6: current_digit = digit6;
        3'd7: current_digit = digit7;
        default: current_digit = 4'd0;
    endcase
end

// 애노드 선택 (Active Low)
always @(*) begin
    case (scan_digit)
        3'd0: anode = 8'b11111110;
        3'd1: anode = 8'b11111101;
        3'd2: anode = 8'b11111011;
        3'd3: anode = 8'b11110111;
        3'd4: anode = 8'b11101111;
        3'd5: anode = 8'b11011111;
        3'd6: anode = 8'b10111111;
        3'd7: anode = 8'b01111111;
        default: anode = 8'b11111111;
    endcase
end

// 7-segment 디코더 (Active Low: 0=ON, 1=OFF)
//   seg[0]=a, seg[1]=b, seg[2]=c, seg[3]=d, seg[4]=e, seg[5]=f, seg[6]=g
always @(*) begin
    case (current_digit)
        4'd0: seg = 7'b1000000;  // 0
        4'd1: seg = 7'b1111001;  // 1
        4'd2: seg = 7'b0100100;  // 2
        4'd3: seg = 7'b0110000;  // 3
        4'd4: seg = 7'b0011001;  // 4
        4'd5: seg = 7'b0010010;  // 5
        4'd6: seg = 7'b0000010;  // 6
        4'd7: seg = 7'b1111000;  // 7
        4'd8: seg = 7'b0000000;  // 8
        4'd9: seg = 7'b0010000;  // 9
        default: seg = 7'b1111111;  // 꺼짐
    endcase
end

endmodule
