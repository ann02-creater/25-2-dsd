module fpga_debugger(
    input clk,              // 100MHz 보드 클럭
    input rstn,             // Active-low 리셋
    input sw_mode,          // SW0: 모드 선택 (0=UART, 1=Debug)
    input uart_rx,          // UART RX 핀
    output uart_tx,         // UART TX 핀
    output [6:0] seg,       // 7-segment 세그먼트
    output [3:0] anode,     // 7-segment 애노드
    output [1:0] led        // LED[0]=RX valid, LED[1]=TX busy
);

// =============================================================================
// 리셋 처리
// =============================================================================
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

// CPU 클럭 선택: sw_mode=0 → 25MHz (UART 모드), sw_mode=1 → ~3Hz (디버그 모드)
wire cpu_clk;
assign cpu_clk = sw_mode ? div[24] : div[1];

// =============================================================================
// UART 신호 (100MHz 도메인)
// =============================================================================
wire [7:0] uart_rx_data;    // UART에서 수신한 데이터
wire uart_rx_valid;         // UART 수신 완료 플래그
wire uart_tx_busy;          // UART 송신 중 플래그

// =============================================================================
// CPU ↔ UART 인터페이스 신호 (CPU 클럭 도메인)
// =============================================================================
wire [7:0] cpu_tx_data;     // CPU → UART 송신 데이터
wire cpu_tx_we;             // CPU → UART 쓰기 활성화
wire cpu_rx_re;             // CPU → UART 읽기 확인

// =============================================================================
// CDC (Clock Domain Crossing): CPU → UART (cpu_clk → 100MHz)
// =============================================================================

// TX Write Enable: 엣지 검출로 펄스 생성
reg [2:0] tx_we_sync;
always @(posedge clk or posedge rst) begin
    if (rst) tx_we_sync <= 3'b000;
    else     tx_we_sync <= {tx_we_sync[1:0], cpu_tx_we};
end
wire tx_we_pulse = tx_we_sync[1] & ~tx_we_sync[2];  // Rising edge

// RX Read Enable: 엣지 검출로 펄스 생성
reg [2:0] rx_re_sync;
always @(posedge clk or posedge rst) begin
    if (rst) rx_re_sync <= 3'b000;
    else     rx_re_sync <= {rx_re_sync[1:0], cpu_rx_re};
end
wire rx_re_pulse = rx_re_sync[1] & ~rx_re_sync[2];  // Rising edge

// TX 데이터 래치 (펄스 시점에 캡처)
reg [7:0] tx_data_latched;
always @(posedge clk or posedge rst) begin
    if (rst) tx_data_latched <= 8'h00;
    else if (tx_we_pulse) tx_data_latched <= cpu_tx_data;
end

// =============================================================================
// CDC (Clock Domain Crossing): UART → CPU (100MHz → cpu_clk)
// =============================================================================

// RX Valid 동기화 (2-FF synchronizer)
reg [1:0] rx_valid_sync;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) rx_valid_sync <= 2'b00;
    else     rx_valid_sync <= {rx_valid_sync[0], uart_rx_valid};
end
wire cpu_rx_valid = rx_valid_sync[1];

// TX Busy 동기화 (2-FF synchronizer)
reg [1:0] tx_busy_sync;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) tx_busy_sync <= 2'b00;
    else     tx_busy_sync <= {tx_busy_sync[0], uart_tx_busy};
end
wire cpu_tx_busy = tx_busy_sync[1];

// RX 데이터 동기화 (2-FF synchronizer for each bit)
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
// 입력 숫자 누적 (UART 모드에서 7-segment 표시용)
// =============================================================================
reg [15:0] input_number;
reg [15:0] display_number;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        input_number <= 16'd0;
        display_number <= 16'd0;
    end else if (uart_rx_valid) begin
        // ASCII '0'-'9' (0x30-0x39)
        if (uart_rx_data >= 8'h30 && uart_rx_data <= 8'h39) begin
            // 숫자 누적 (최대 9999)
            if (input_number <= 16'd999)
                input_number <= input_number * 10 + (uart_rx_data - 8'h30);
            display_number <= input_number * 10 + (uart_rx_data - 8'h30);
        end
        // Enter (0x0D) 또는 Newline (0x0A)
        else if (uart_rx_data == 8'h0D || uart_rx_data == 8'h0A) begin
            input_number <= 16'd0;  // 다음 입력을 위해 리셋
            // display_number는 유지 (마지막 입력값 표시)
        end
    end
end

// =============================================================================
// DATA PATH (CPU) 인스턴스
// =============================================================================
wire [31:0] PC;
wire [31:0] inst_out;
wire forwarding_active, hazard_stall;

// 연결하지 않는 와이어들
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

    // UART 인터페이스 (동기화된 신호 사용)
    .uart_tx_data_out(cpu_tx_data),
    .uart_tx_we_out(cpu_tx_we),
    .uart_rx_re_out(cpu_rx_re),
    .uart_rx_data_in(cpu_rx_data),
    .uart_rx_valid_in(cpu_rx_valid),
    .uart_tx_busy_in(cpu_tx_busy),

    .forwarding_active_ext(forwarding_active),
    .hazard_stall_ext(hazard_stall)
);

// =============================================================================
// UART 인스턴스 (항상 100MHz에서 동작)
// =============================================================================
uart u_uart (
    .clk(clk),
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd868),          // 100MHz / 868 ≈ 115200 baud
    .reg_dat_di(tx_data_latched),   // CDC를 통해 래치된 데이터
    .reg_dat_do(uart_rx_data),
    .reg_dat_we(tx_we_pulse),       // CDC를 통한 펄스
    .reg_dat_re(rx_re_pulse),       // CDC를 통한 펄스
    .tx_busy(uart_tx_busy),
    .rx_valid(uart_rx_valid)
);

// =============================================================================
// LED 출력 (디버깅용)
// =============================================================================
assign led[0] = uart_rx_valid;  // UART RX 데이터 수신
assign led[1] = uart_tx_busy;   // UART TX 전송 중

// =============================================================================
// 7-Segment 디스플레이
// =============================================================================
reg [15:0] disp_value;

always @(*) begin
    if (sw_mode)
        disp_value = PC[15:0];      // 디버그 모드: PC 값 표시
    else
        disp_value = display_number; // UART 모드: 입력 숫자 표시
end

Four_Digit_Seven_Segment_Driver_2 segger (
    .clk(clk),
    .num(disp_value),
    .Anode(anode),
    .LED_out(seg)
);

endmodule
