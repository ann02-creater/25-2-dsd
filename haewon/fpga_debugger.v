// UART Test - 50MHz CPU clock (same as UART baud rate generation)
// Uses clock divider for CPU, but UART baud rate adjusted accordingly
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

// Clock divider - 50MHz CPU clock
reg div_2;
always @(posedge clk or posedge rst) begin
    if (rst) div_2 <= 0;
    else     div_2 <= ~div_2;
end
wire cpu_clk = div_2;  // 100MHz / 2 = 50MHz

// UART signals
wire [7:0] uart_rx_data;
wire uart_rx_valid;
wire uart_tx_busy;

// CPU signals
wire [7:0] tx_data_cpu;
wire tx_we_cpu;
wire rx_re_cpu;

// Data path signals
wire [31:0] PC;
wire [31:0] PC_inc, PC_gen_out, PC_in;
wire [31:0] data_read_1, data_read_2, write_data, imm_out, alu_mux, alu_out, data_mem_out;
wire [31:0] inst_out;
wire forwarding_active, hazard_stall;

// DATA PATH - runs on 50MHz
data_path dp(
    .clk(cpu_clk),          // 50MHz
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
    
    // UART interface
    .uart_tx_data_out(tx_data_cpu),
    .uart_tx_we_out(tx_we_cpu),
    .uart_rx_re_out(rx_re_cpu),
    .uart_rx_data_in(uart_rx_data),
    .uart_rx_valid_in(uart_rx_valid),
    .uart_tx_busy_in(uart_tx_busy),
    
    .forwarding_active_ext(forwarding_active),
    .hazard_stall_ext(hazard_stall)
);

// UART - runs on 50MHz (same as CPU, no CDC needed)
// Baud rate: 50MHz / 434 = 115207 baud (close to 115200)
uart u_uart (
    .clk(cpu_clk),          // 50MHz - same as CPU!
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd434),  // 50MHz / 434 = 115200 baud
    .reg_dat_di(tx_data_cpu),
    .reg_dat_do(uart_rx_data),
    .reg_dat_we(tx_we_cpu),
    .reg_dat_re(rx_re_cpu),
    .tx_busy(uart_tx_busy),
    .rx_valid(uart_rx_valid)
);

// LED - debug indicators
assign led[0] = uart_rx_valid;
assign led[1] = uart_tx_busy;

// 7-segment display (runs on 100MHz for smooth display)
wire [15:0] disp = sw_pc ? PC[15:0] : {8'h00, uart_rx_data};

Four_Digit_Seven_Segment_Driver_2 segger (
    .clk(clk),              // 100MHz for display refresh
    .num(disp),
    .Anode(anode),
    .LED_out(seg)
);

endmodule
