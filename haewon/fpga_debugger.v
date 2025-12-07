module fpga_debugger(
    input clk,
    input rstn,
    input sw_pc,        // SW0: 0=UART RX data, 1=PC
    input uart_rx,
    output uart_tx,
    output [6:0] seg,
    output [3:0] anode,
    output [1:0] led
);

wire rst = ~rstn;

// Clock divider
reg [1:0] div;
always @(posedge clk or posedge rst) begin
    if (rst) div <= 0;
    else     div <= div + 1;
end
wire cpu_clk = div[1];  // 25MHz

// UART signals
wire [7:0] uart_rx_data;
wire uart_rx_valid;
wire uart_tx_busy;

// CPU signals
wire [7:0] tx_data_cpu;
wire tx_we_cpu;
wire rx_re_cpu;

// CDC: CPU to UART (cpu_clk -> 100MHz)
reg [2:0] tx_we_sync;
always @(posedge clk or posedge rst) begin
    if (rst) tx_we_sync <= 0;
    else     tx_we_sync <= {tx_we_sync[1:0], tx_we_cpu};
end
wire tx_we_pulse = tx_we_sync[1] & ~tx_we_sync[2];

reg [2:0] rx_re_sync;
always @(posedge clk or posedge rst) begin
    if (rst) rx_re_sync <= 0;
    else     rx_re_sync <= {rx_re_sync[1:0], rx_re_cpu};
end
wire rx_re_pulse = rx_re_sync[1] & ~rx_re_sync[2];

// CDC: UART to CPU (100MHz -> cpu_clk)
reg [1:0] rx_valid_sync;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) rx_valid_sync <= 0;
    else     rx_valid_sync <= {rx_valid_sync[0], uart_rx_valid};
end

reg [1:0] tx_busy_sync;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) tx_busy_sync <= 0;
    else     tx_busy_sync <= {tx_busy_sync[0], uart_tx_busy};
end

reg [7:0] rx_data_sync1, rx_data_sync2;
always @(posedge cpu_clk or posedge rst) begin
    if (rst) begin
        rx_data_sync1 <= 0;
        rx_data_sync2 <= 0;
    end else begin
        rx_data_sync1 <= uart_rx_data;
        rx_data_sync2 <= rx_data_sync1;
    end
end

// Data path
wire [31:0] PC;
wire [31:0] PC_inc, PC_gen_out, PC_in;
wire [31:0] data_read_1, data_read_2, write_data, imm_out, alu_mux, alu_out, data_mem_out;
wire [31:0] inst_out;
wire forwarding_active, hazard_stall;

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
    .uart_rx_data_in(rx_data_sync2),
    .uart_rx_valid_in(rx_valid_sync[1]),
    .uart_tx_busy_in(tx_busy_sync[1]),
    .forwarding_active_ext(forwarding_active),
    .hazard_stall_ext(hazard_stall)
);

// UART
uart u_uart (
    .clk(clk),
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd868),
    .reg_dat_di(tx_data_cpu),
    .reg_dat_do(uart_rx_data),
    .reg_dat_we(tx_we_pulse),
    .reg_dat_re(rx_re_pulse),
    .tx_busy(uart_tx_busy),
    .rx_valid(uart_rx_valid)
);

// LED
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
