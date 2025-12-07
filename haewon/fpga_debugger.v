// Simplified UART test - Single clock domain (100MHz)
// No CDC - CPU and UART run on same clock
module fpga_debugger(
    input clk,
    input rstn,
    input sw_pc,
    input uart_rx,
    output uart_tx,
    output [6:0] seg,
    output [3:0] anode,
    output [1:0] led
);

wire rst = ~rstn;

// All modules run on 100MHz clock - NO clock divider
// This eliminates CDC issues completely

// UART signals
wire [7:0] uart_rx_data;
wire uart_rx_valid;
wire uart_tx_busy;

// CPU signals - directly connected, no CDC needed
wire [7:0] tx_data_cpu;
wire tx_we_cpu;
wire rx_re_cpu;

// Data path signals
wire [31:0] PC;
wire [31:0] PC_inc, PC_gen_out, PC_in;
wire [31:0] data_read_1, data_read_2, write_data, imm_out, alu_mux, alu_out, data_mem_out;
wire [31:0] inst_out;
wire forwarding_active, hazard_stall;

// DATA PATH - runs on 100MHz
data_path dp(
    .clk(clk),              // 100MHz - same as UART
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
    
    // Direct connection - no CDC
    .uart_tx_data_out(tx_data_cpu),
    .uart_tx_we_out(tx_we_cpu),
    .uart_rx_re_out(rx_re_cpu),
    .uart_rx_data_in(uart_rx_data),
    .uart_rx_valid_in(uart_rx_valid),
    .uart_tx_busy_in(uart_tx_busy),
    
    .forwarding_active_ext(forwarding_active),
    .hazard_stall_ext(hazard_stall)
);

// UART - runs on 100MHz
uart u_uart (
    .clk(clk),              // 100MHz
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd868),  // 100MHz / 868 = 115200 baud
    .reg_dat_di(tx_data_cpu),
    .reg_dat_do(uart_rx_data),
    .reg_dat_we(tx_we_cpu), // Direct connection
    .reg_dat_re(rx_re_cpu), // Direct connection
    .tx_busy(uart_tx_busy),
    .rx_valid(uart_rx_valid)
);

// LED - debug indicators
assign led[0] = uart_rx_valid;
assign led[1] = uart_tx_busy;

// 7-segment display
wire [15:0] disp = sw_pc ? PC[15:0] : {8'h00, uart_rx_data};

Four_Digit_Seven_Segment_Driver_2 segger (
    .clk(clk),
    .num(disp),
    .Anode(anode),
    .LED_out(seg)
);

endmodule
