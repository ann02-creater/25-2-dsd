`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: ps2_kbd_new.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원 (based on lab material)
//
// Description:
//   PS2 키보드 디코더. 스캔코드를 ASCII로 변환.
//   프레임 구조: start(1) + data(8) + parity(1) + stop(1) = 11 bits
//
// Change History:
//   2024.12.11 - Lab 자료 기반으로 통합
//////////////////////////////////////////////////////////////////////////////////

`define TIMER_120U_BIT_SIZE 13
`define FRAME_BIT_NUM 11
`define ready_st 'b0
`define ready_ack_st 'b1
`define RELEASE_CODE 8'hF0
`define EXTENDED_CODE 8'hE0
`define TIMER_120U_TERMINAL_VAL 6000

module ps2_kbd_new(
    input wire clk,
    input wire rst,
    input wire ps2_clk,
    input wire ps2_data,
    input wire read,
    output reg [7:0] scancode,
    output wire data_ready,
    output reg released,
    output reg err_ind
);
	 
localparam S_H = 2'b00, S_L = 2'b01, S_L2H = 2'b11, S_H2L = 2'b10;

reg [1:0] st, nx_st;
reg [1:0] nx_st2, st2;

reg ps2_clk_d, ps2_clk_s, ps2_data_d, ps2_data_s;
wire ps2_clk_rising_edge, ps2_clk_falling_edge;
wire rst_timer, shift_done;
reg [`FRAME_BIT_NUM - 1 : 0] q;
wire shift;
reg [3:0] bit_cnt;
wire reset_bit_cnt;
wire timer_timeout;
reg [`TIMER_120U_BIT_SIZE-1:0] timer_cnt;
wire got_release;
wire output_strobe;
reg hold_release;
wire extended;
reg hold_extended;
wire err;
reg parity_err, ss_bits_err;
reg p;
reg valid;
reg shift_flag;

// Synchronize PS2 signals to system clock
always @(posedge rst, posedge clk) begin : sync_reg
    if(rst == 'b1) begin
        ps2_clk_d <= 'b1;
        ps2_data_d <= 'b1;
        ps2_clk_s<= 'b1;
        ps2_data_s <= 'b1;
    end
    else begin
        ps2_clk_d <= ps2_clk;
        ps2_data_d <= ps2_data;
        ps2_clk_s <= ps2_clk_d;
        ps2_data_s <= ps2_data_d;
    end
end

assign ps2_clk_rising_edge = !ps2_clk_s & ps2_clk_d;
assign ps2_clk_falling_edge = !ps2_clk_d & ps2_clk_s;

// PS2 clock edge detection FSM
always @(posedge clk) begin : state_reg
    if(rst == 'b1)
        st <= S_H;
    else
        st <= nx_st;
end
	
always @(*) begin
    case (st) 
        S_L : nx_st = (ps2_clk_rising_edge == 'b1) ? S_L2H : S_L;
        S_L2H : nx_st = S_H;
        S_H : nx_st = (ps2_clk_falling_edge == 'b1) ? S_H2L : S_H;
        S_H2L : nx_st = S_L;
        default : nx_st = S_H;						
    endcase
end

assign shift = (st == S_H2L) ? 'b1 : 'b0;
assign rst_timer = (st == S_H2L || st == S_L2H) ? 'b1 : 'b0;

// Bit counter
always @(posedge clk) begin : cnt_bit_num 
    if((rst == 'b1) || (shift_done == 'b1))
        bit_cnt <= 4'b0;
    else if(reset_bit_cnt == 'b1) 
        bit_cnt <= 4'b0;
    else if(shift == 'b1)
        bit_cnt <= bit_cnt + 'b1;
end 

assign timer_timeout = (timer_cnt == `TIMER_120U_TERMINAL_VAL) ? 'b1 : 'b0;
assign reset_bit_cnt = (timer_timeout == 'b1 && st == S_H && ps2_clk_s == 'b1) ? 'b1 : 'b0;

// 120 us timer
always @(posedge clk) begin : timer 
    if(rst_timer == 'b1)
        timer_cnt <= 'b0;
    else if(timer_timeout == 'b0)
        timer_cnt <= timer_cnt + 'b1;	
end

// Shift register (11-bit SIPO)
always @(posedge clk) begin : shift_R 
    if(rst == 'b1) 
        q <= 'b0;
    else if(shift == 'b1) 
        q <= {ps2_data_s, q[`FRAME_BIT_NUM-1 : 1]};
end

assign shift_done = (bit_cnt == `FRAME_BIT_NUM) ? 'b1 : 'b0;
assign got_release = (q[8:1] == `RELEASE_CODE) && (shift_done == 'b1) ? 'b1 : 'b0;
assign extended = (q[8:1] == `EXTENDED_CODE) && (shift_done == 'b1) ? 'b1 : 'b0;
assign output_strobe = ((shift_done == 'b1) && (got_release == 'b0) && (extended == 'b0)) ? 'b1 : 'b0;

always @(posedge clk) begin : latch_released 
    if(rst == 'b1 || output_strobe == 'b1)
        hold_release <= 'b0;
    else if(got_release == 'b1)
        hold_release <= 'b1;
end
	
always @(posedge clk) begin : latch_extended
    if(rst == 'b1 || output_strobe == 'b1)
        hold_extended <= 'b0;
    else if(extended == 'b1)
        hold_extended <= 'b1;
end

// Data ready FSM
always @(posedge clk) begin : comm_state_reg
    if(rst == 'b1) 
        st2 <= `ready_ack_st;
    else
        st2 <= nx_st2;
end 
	
always @(st2, output_strobe, read) begin 
    case (st2) 
        `ready_ack_st : 
            nx_st2 = (output_strobe == 'b1) ? `ready_st : `ready_ack_st;
        `ready_st :
            nx_st2 = (read == 'b1) ? `ready_ack_st : `ready_st;
        default : 
            nx_st2 = `ready_ack_st;						
    endcase
end
	
assign data_ready = (st2 == `ready_st) ? 'b1 : 'b0;

// Scancode to ASCII conversion
always @(posedge clk) begin : send_output
    if(rst == 'b1) begin
        scancode = 'b0;
        shift_flag = 'b0;
        released = 'b1;
        err_ind = 'b0;
    end 
    else if(output_strobe == 'b1) begin
        scancode = q[8:1];
        released = hold_release;
        err_ind = err;
        
        if(shift_flag == 'b1) begin
            // Shift + key combinations
            valid = 'b1;
            case (q[8:1])
                'h16 : scancode = 'h21; // !
                'h1E : scancode = 'h40; // @
                'h26 : scancode = 'h23; // #
                'h25 : scancode = 'h24; // $
                'h2E : scancode = 'h25; // %
                'h36 : scancode = 'h5E; // ^
                'h3D : scancode = 'h26; // &
                'h3E : scancode = 'h2A; // *
                'h46 : scancode = 'h28; // (
                'h45 : scancode = 'h29; // )
                default : begin
                    scancode = scancode;
                    valid = 'b0;
                end
            endcase
            
            if(hold_release == 'b1) begin
                valid = 'b1;
                case (q[8:1])
                    'h12 : begin shift_flag = 'b0; scancode = scancode; end
                    'h59 : begin shift_flag = 'b0; scancode = scancode; end
                    default : begin scancode = scancode; valid = 'b0; end
                endcase
            end
        end
        else if (hold_extended == 'b1) begin
            valid = 'b1;
            case (q[8:1])
                'h5A : scancode = 'h0D; // Numpad ENTER
                default : begin scancode = scancode; valid = 'b0; end
            endcase
        end
        else begin
            // Normal keys
            valid = 'b1;
            case (q[8:1])
                // Numbers (main keyboard)
                'h16 : scancode = 'h31; // 1
                'h1E : scancode = 'h32; // 2
                'h26 : scancode = 'h33; // 3
                'h25 : scancode = 'h34; // 4
                'h2E : scancode = 'h35; // 5
                'h36 : scancode = 'h36; // 6
                'h3D : scancode = 'h37; // 7
                'h3E : scancode = 'h38; // 8
                'h46 : scancode = 'h39; // 9
                'h45 : scancode = 'h30; // 0
                
                // Numbers (numpad)
                'h69 : scancode = 'h31; // 1
                'h72 : scancode = 'h32; // 2
                'h7A : scancode = 'h33; // 3
                'h6B : scancode = 'h34; // 4
                'h73 : scancode = 'h35; // 5
                'h74 : scancode = 'h36; // 6
                'h6C : scancode = 'h37; // 7
                'h75 : scancode = 'h38; // 8
                'h7D : scancode = 'h39; // 9
                'h70 : scancode = 'h30; // 0
                
                // Special keys
                'h66 : scancode = 'h08; // BACKSPACE
                'h5A : scancode = 'h0D; // ENTER
                'h29 : scancode = 'h20; // SPACE
                
                // Shift keys
                'h12 : begin scancode = scancode; shift_flag = 'b1; end
                'h59 : begin scancode = scancode; shift_flag = 'b1; end
                
                default : begin scancode = scancode; valid = 'b0; end
            endcase
        end				
    end
    else begin
        scancode = scancode;
        err_ind = err_ind;
        released = released;
    end
end
	
// Parity checking
always @(q) begin : err_chk 
    p = q[0] ^ q[1] ^ q[2] ^ q[3] ^ q[4] ^ q[5] ^ q[6] ^ q[7] ^ q[8] ^ q[9] ^ q[10];	
    parity_err = (p == 'b1) ? 1'b0 : 1'b1;
    ss_bits_err = (q[0] == 'b1 || q[10] == 'b0) ? 1'b1 : 1'b0;
end
	
assign err = parity_err || ss_bits_err;

endmodule
