`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: top
// Description: Simplified top module for RISC-V CPU with instruction display
//              - switch[0]: Select current PC instruction (0) or PC+4 instruction (1)
//              - led[0]: Heartbeat LED showing CPU is running
//              - 7-segment 8-digit: Display instruction mnemonic
//////////////////////////////////////////////////////////////////////////////////

module top(
    input clk,
    input rst,
    input switch_0,          // Instruction select: 0=current PC, 1=PC+4
    input uart_rx,
    output uart_tx,
    output led_heartbeat,    // Heartbeat LED
    output [6:0] seg_out,    // 7-segment cathodes
    output [7:0] seg_sel     // 7-segment anodes (8 digits)
);

    // Internal signals from data_path
    wire [31:0] inst_out;
    wire [31:0] PC;
    wire [15:0] led_reg;  // Not used externally, but kept for data_path
    wire [7:0]  tx_data;
    wire        tx_we;
    wire        rx_re;
    wire [7:0]  rx_data;
    wire        rx_valid;
    wire        tx_busy;
    
    // Debug signals (not used in simplified version, but kept for data_path compatibility)
    wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;
    wire [1:0] alu_op;
    wire z_flag;
    wire [4:0] alu_ctrl_out;
    wire [31:0] PC_inc, PC_gen_out, PC_in;
    wire [31:0] data_read_1, data_read_2, write_data, imm_out, shift, alu_mux, alu_out, data_mem_out;

    // Instantiate data_path (RISC-V pipeline CPU core)
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
        .led_reg_out(led_reg),
        .uart_tx_data_out(tx_data),
        .uart_tx_we_out(tx_we),
        .uart_rx_re_out(rx_re),
        .uart_rx_data_in(rx_data),
        .uart_rx_valid_in(rx_valid),
        .uart_tx_busy_in(tx_busy)
    );

    // Instantiate UART
    uart u_uart(
        .clk(clk),
        .resetn(!rst),
        .ser_tx(uart_tx),
        .ser_rx(uart_rx),
        .cfg_divider(16'd868),  // 115200 baud @ 100MHz
        .reg_dat_di(tx_data),
        .reg_dat_do(rx_data),
        .reg_dat_we(tx_we),
        .reg_dat_re(rx_re),
        .tx_busy(tx_busy),
        .rx_valid(rx_valid)
    );

    // Instruction selection: current PC or PC+4
    // Note: PC+4 instruction needs to be read from BRAM
    wire [31:0] pc_plus_4 = PC + 4;
    wire [31:0] display_inst;
    
    // For simplicity, we'll display current instruction when switch_0=0
    // and show PC+4 value (not instruction) when switch_0=1
    // To show actual PC+4 instruction would require additional BRAM read port
    assign display_inst = switch_0 ? {pc_plus_4[15:0], 16'h0000} : inst_out;

    // Instruction decoder: converts instruction to 7-segment patterns
    wire [6:0] seg0_pattern, seg1_pattern, seg2_pattern, seg3_pattern;
    wire [6:0] seg4_pattern, seg5_pattern, seg6_pattern, seg7_pattern;
    
    inst_decoder decoder(
        .instruction(display_inst),
        .seg0(seg0_pattern),
        .seg1(seg1_pattern),
        .seg2(seg2_pattern),
        .seg3(seg3_pattern),
        .seg4(seg4_pattern),
        .seg5(seg5_pattern),
        .seg6(seg6_pattern),
        .seg7(seg7_pattern)
    );

    // 7-segment driver: multiplexes 8 digits
    seven_segment_8_driver seg_driver(
        .clk(clk),
        .rst(rst),
        .seg0(seg0_pattern),
        .seg1(seg1_pattern),
        .seg2(seg2_pattern),
        .seg3(seg3_pattern),
        .seg4(seg4_pattern),
        .seg5(seg5_pattern),
        .seg6(seg6_pattern),
        .seg7(seg7_pattern),
        .seg_out(seg_out),
        .seg_sel(seg_sel)
    );

    // Heartbeat LED: toggles ~0.75Hz to show CPU is running
    reg [25:0] heartbeat_counter;
    always @(posedge clk) begin
        if (rst)
            heartbeat_counter <= 0;
        else
            heartbeat_counter <= heartbeat_counter + 1;
    end
    
    assign led_heartbeat = heartbeat_counter[25];

endmodule
