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
    
    // --- DEBUG FEATURE: Capture and display generic UART TX data on 7-segment ---
    reg [7:0] tx_buffer [7:0]; // 8-character buffer
    integer i;
    
    always @(posedge clk) begin
        if (rst) begin
            for(i=0; i<8; i=i+1) tx_buffer[i] <= 8'h20; // Initialize with spaces
        end else if (tx_we) begin
            // Shift left and insert new char at right (Index 0 is rightmost digit in our logic)
            // But for display reading left-to-right (Seg7..Seg0), usually Seg7 is left.
            // Let's shift such that new char enters at Seg0 (Right) and scrolls to Seg7 (Left).
            // So tx_buffer[0] = new_char, tx_buffer[1] = old_buffer[0]...
            tx_buffer[0] <= tx_data;
            for(i=1; i<8; i=i+1) tx_buffer[i] <= tx_buffer[i-1];
        end
    end

    // ASCII to 7-segment decoding function
    function [6:0] char_to_seg_top;
        input [7:0] c;
        begin
            case (c)
                "0": char_to_seg_top = 7'b1000000;
                "1": char_to_seg_top = 7'b1111001;
                "2": char_to_seg_top = 7'b0100100;
                "3": char_to_seg_top = 7'b0110000;
                "4": char_to_seg_top = 7'b0011001;
                "5": char_to_seg_top = 7'b0010010;
                "6": char_to_seg_top = 7'b0000010;
                "7": char_to_seg_top = 7'b1111000;
                "8": char_to_seg_top = 7'b0000000;
                "9": char_to_seg_top = 7'b0010000;
                "A": char_to_seg_top = 7'b0001000; "a": char_to_seg_top = 7'b0001000;
                "B": char_to_seg_top = 7'b0000011; "b": char_to_seg_top = 7'b0000011;
                "C": char_to_seg_top = 7'b1000110; "c": char_to_seg_top = 7'b1000110;
                "D": char_to_seg_top = 7'b0100001; "d": char_to_seg_top = 7'b0100001;
                "E": char_to_seg_top = 7'b0000110; "e": char_to_seg_top = 7'b0000110;
                "F": char_to_seg_top = 7'b0001110; "f": char_to_seg_top = 7'b0001110;
                "G": char_to_seg_top = 7'b0010000; "g": char_to_seg_top = 7'b0010000;
                "H": char_to_seg_top = 7'b0001001; "h": char_to_seg_top = 7'b0001001;
                "I": char_to_seg_top = 7'b1111001; "i": char_to_seg_top = 7'b1111001;
                "J": char_to_seg_top = 7'b1100001; "j": char_to_seg_top = 7'b1100001;
                "L": char_to_seg_top = 7'b1000111; "l": char_to_seg_top = 7'b1000111;
                "N": char_to_seg_top = 7'b0000000; "n": char_to_seg_top = 7'b1101010; // n
                "O": char_to_seg_top = 7'b1000000; "o": char_to_seg_top = 7'b0100011; // o
                "P": char_to_seg_top = 7'b0001100; "p": char_to_seg_top = 7'b0001100;
                "Q": char_to_seg_top = 7'b0011000; "q": char_to_seg_top = 7'b0011000;
                "R": char_to_seg_top = 7'b0001000; "r": char_to_seg_top = 7'b0101111;
                "S": char_to_seg_top = 7'b0010010; "s": char_to_seg_top = 7'b0010010;
                "T": char_to_seg_top = 7'b0000111; "t": char_to_seg_top = 7'b0000111;
                "U": char_to_seg_top = 7'b1000001; "u": char_to_seg_top = 7'b0011100; // u
                "V": char_to_seg_top = 7'b0011100; "v": char_to_seg_top = 7'b0011100; // u looks like v
                "Y": char_to_seg_top = 7'b0010001; "y": char_to_seg_top = 7'b0010001;
                "-": char_to_seg_top = 7'b0111111;
                "=": char_to_seg_top = 7'b0110111; // double dash approx
                default: char_to_seg_top = 7'b1111111; // blank
            endcase
        end
    endfunction
    
    // Select between Instruction Decoder (switch=0) and TX Buffer (switch=1)
    wire [6:0] s0, s1, s2, s3, s4, s5, s6, s7;
    
    assign s0 = switch_0 ? char_to_seg_top(tx_buffer[0]) : seg0_pattern;
    assign s1 = switch_0 ? char_to_seg_top(tx_buffer[1]) : seg1_pattern;
    assign s2 = switch_0 ? char_to_seg_top(tx_buffer[2]) : seg2_pattern;
    assign s3 = switch_0 ? char_to_seg_top(tx_buffer[3]) : seg3_pattern;
    assign s4 = switch_0 ? char_to_seg_top(tx_buffer[4]) : seg4_pattern;
    assign s5 = switch_0 ? char_to_seg_top(tx_buffer[5]) : seg5_pattern;
    assign s6 = switch_0 ? char_to_seg_top(tx_buffer[6]) : seg6_pattern;
    assign s7 = switch_0 ? char_to_seg_top(tx_buffer[7]) : seg7_pattern;

    seven_segment_8_driver seg_driver(
        .clk(clk),
        .rst(rst),
        .seg0(s0),
        .seg1(s1),
        .seg2(s2),
        .seg3(s3),
        .seg4(s4),
        .seg5(s5),
        .seg6(s6),
        .seg7(s7),
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
