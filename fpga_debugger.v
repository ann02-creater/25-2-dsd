`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/01/2019 04:02:07 PM
// Design Name: 
// Module Name: fpga_debugger
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fpga_debugger(input seg_clk, input clk, input rst, 
input [1:0]led_sel, input [3:0]seg_sel, 
input uart_rx,
output [6:0]seg, output [0:3]anode, output reg [0:15]led,
output uart_tx);

wire [31:0]inst_out;
wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;
wire [1:0]alu_op;
wire z_flag;
wire [3:0]alu_ctrl_out;
wire [31:0]PC_inc;
wire [31:0]PC_gen_out;
wire [31:0]PC, PC_in;
wire [31:0]data_read_1, data_read_2, write_data, imm_out, shift, alu_mux, alu_out, data_mem_out;
wire [15:0] led_reg;
wire [15:0] led_reg_wire;
    wire [7:0]  tx_data;
    wire        tx_we;
    wire        rx_re;
    wire [7:0]  rx_data;
    wire        rx_valid;
    wire        tx_busy;

data_path dp(
    .clk(clk),
    .rst(rst),
    .inst_out_ext(inst_out),
    .branch_ext(branch),
    .mem_read_ext(mem_read),
    .mem_to_reg_ext(mem_to_reg),
    .mem_write_ext(mem_write),
    .alu_src_ext(alu_src),
    .reg_write_ext(reg_write),
    .alu_op_ext(alu_op),
    .z_flag_ext(z_flag),
    .alu_ctrl_out_ext(alu_ctrl_out),
    .PC_inc_ext(PC_inc),
    .pc_gen_out_ext(PC_gen_out),
    .PC_ext(PC),
    .PC_in_ext(PC_in),
    .data_read_1_ext(data_read_1),
    .data_read_2_ext(data_read_2),
    .write_data_ext(write_data),
    .imm_out_ext(imm_out),
    .shift_ext(shift),
    .alu_mux_ext(alu_mux),
    .alu_out_ext(alu_out),
    .data_mem_out_ext(data_mem_out),
    .led_reg_out(led_reg) // LED 제어용 출력 포트 연결
    .uart_tx_data_out(tx_data),
    .uart_tx_we_out(tx_we),
    .uart_rx_re_out(rx_re),
    .uart_rx_data_in(rx_data),
    .uart_rx_valid_in(rx_valid),
    .uart_tx_busy_in(tx_busy)
);

uart u_uart (
        .clk(clk),
        .resetn(!rst),
        .ser_tx(uart_tx),
        .ser_rx(uart_rx),
        .cfg_divider(16'd87), // ★주의: simpleuart 내부 카운터 비트수에 따라 값 조정 필요
                             // 여기서는 간단히 8비트로 가정했으나, 정확한 계산 필요.
                             // 100MHz / 115200bps = 868. 
                             // simpleuart 코드를 보니 cfg_divider가 8비트네요.
                             // 100MHz는 8비트로 커버 안됩니다.
                             // -> simpleuart.v의 cfg_divider를 16비트로 늘리거나
                             //    임시로 10416 상수를 코드 내부에 박아버리는 게 낫습니다.
        .reg_dat_di(tx_data),
    .reg_dat_do(rx_data), // 사용 안 함 (rx_data는 내부 레지스터에서 땀)
        .reg_dat_we(tx_we),
        .reg_dat_re(rx_re),
        .tx_busy(tx_busy),
        .rx_valid(rx_valid)
    );

always @(*) begin
    case (led_sel)
        2'b00: led = inst_out[15:0];
        2'b01: led = inst_out[31:16];
        2'b10: led = {branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write, alu_op, z_flag};
        2'b11: led = led_reg_wire; // 메모리에서 제어된 LED 상태 출력
        default: led = 16'b0;
    endcase
end

reg [12:0]disp;

Four_Digit_Seven_Segment_Driver_2 segger (seg_clk, disp, anode, seg);


always @(*) begin

    case(seg_sel)
        4'b0000: disp = PC;
        4'b0001: disp = PC_inc;
        4'b0010: disp = PC_gen_out;
        4'b0011: disp = PC_in;
        4'b0100: disp = data_read_1;
        4'b0101: disp = data_read_2;
        4'b0110: disp = write_data;
        4'b0111: disp = imm_out;
        4'b1000: disp = shift;
        4'b1001: disp = alu_mux;
        4'b1010: disp = alu_out;
        4'b1011: disp = data_mem_out;
        default: disp = 32'hffffffff;
    endcase
end


endmodule
