module fpga_debugger(
    input clk,
    input rstn,
    input sw_pc,        // SW0: PC 출력 on/off
    input uart_rx,
    output uart_tx,
    output [6:0] seg,
    output [3:0] anode,
    output [2:0] led     // LED 3개만 사용 (디버깅용)
);
wire rst;
assign rst = ~rstn;

wire [31:0] PC;
wire [31:0] PC_inc, PC_gen_out, PC_in;
wire [31:0] data_read_1, data_read_2, write_data, imm_out, alu_mux, alu_out, data_mem_out;
wire [31:0] inst_out;

// UART wires
wire [7:0] tx_data;
wire tx_we;
wire rx_re;
wire [7:0] rx_data;
wire rx_valid;
wire tx_busy;

// -----------------------------
// DATA PATH INSTANCE
// -----------------------------
reg [25:0] div;
always @(posedge clk or posedge rst) begin
    if (rst) div <= 0;
    else     div <= div + 1;
end

wire slow_clk = div[24]; 

wire forwarding_active;
wire hazard_stall;

data_path dp(
//    .clk(clk),
    .clk(clk),
    .rst(rst),
    .inst_out_ext(inst_out),
    .branch_ext(),              // 연결 안함 (디버깅 전용)
    .mem_read_ext(),            // 연결 안함
    .mem_to_reg_ext(),          // 연결 안함
    .mem_write_ext(),           // 연결 안함
    .alu_src_ext(),             // 연결 안함
    .reg_write_ext(),           // 연결 안함
    .alu_op_ext(),              // 연결 안함
    .z_flag_ext(),              // 연결 안함
    .alu_ctrl_out_ext(),        // 연결 안함
    .PC_inc_ext(PC_inc),
    .pc_gen_out_ext(PC_gen_out),
    .PC_ext(PC),
    .PC_in_ext(PC_in),
    .data_read_1_ext(data_read_1),
    .data_read_2_ext(data_read_2),
    .write_data_ext(write_data),
    .imm_out_ext(imm_out),
    .shift_ext(),               // 연결 안함
    .alu_mux_ext(alu_mux),
    .alu_out_ext(alu_out),
    .data_mem_out_ext(data_mem_out),
    .led_reg_out(),             // 연결 안함 (사용하지 않음)

    .uart_tx_data_out(tx_data),
    .uart_tx_we_out(tx_we),
    .uart_rx_re_out(rx_re),
    .uart_rx_data_in(rx_data),
    .uart_rx_valid_in(rx_valid),
    .uart_tx_busy_in(tx_busy),

    .forwarding_active_ext(forwarding_active),
    .hazard_stall_ext(hazard_stall)
);

// -----------------------------
// UART INSTANCE
// -----------------------------
uart u_uart (
    .clk(clk),
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd868),
    .reg_dat_di(tx_data),
    .reg_dat_do(rx_data),
    .reg_dat_we(tx_we),
    .reg_dat_re(rx_re),
    .tx_busy(tx_busy),
    .rx_valid(rx_valid)
);

// -----------------------------
// LED 출력: 디버깅 정보 표시
// -----------------------------
assign led[0] = rx_valid;         // UART RX 데이터 수신 여부 (테스트용)
assign led[1] = tx_busy;          // UART TX 전송 중 여부
assign led[2] = |rx_data;         // RX 데이터가 0이 아닌지 확인


// -----------------------------
// 7-SEG OUTPUT
// sw_pc = 0: UART RX 데이터 표시 (테스트용)
// sw_pc = 1: PC[15:0] 표시
// -----------------------------
reg [15:0] disp;

always @(*) begin
    if (sw_pc)
        disp = PC[15:0];
    else
        disp = {8'h00, rx_data}; // UART RX 데이터 표시
end

Four_Digit_Seven_Segment_Driver_2 segger (
    .clk(clk),
    .num(disp[15:0]),  // 16비트 전체 전달 (하위 16비트 전체 표시)
    .Anode(anode),
    .LED_out(seg)
);

endmodule
