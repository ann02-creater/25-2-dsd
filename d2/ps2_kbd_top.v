`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: ps2_kbd_top.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원 (based on lab material)
//
// Description:
//   PS2 키보드 최상위 모듈. ps2_kbd_new와 debounce_pulse를 통합.
//
// Change History:
//   2024.12.11 - Lab 자료 기반으로 통합
//////////////////////////////////////////////////////////////////////////////////

module ps2_kbd_top(
    input clk,
    input rst,
    input ps2clk,
    input ps2data,
    output [7:0] scancode,
    output Released,
    output err_ind
);

wire req, released_out;
reg ack;

ps2_kbd_new ps2 (
    .clk(clk), 
    .rst(rst), 
    .ps2_clk(ps2clk), 
    .ps2_data(ps2data), 
    .scancode(scancode), 
    .read(ack), 
    .data_ready(req), 
    .released(released_out), 
    .err_ind(err_ind)
);
	 
debounce_pulse pulse (
    .clk(clk), 
    .rst(rst), 
    .Din(released_out), 
    .Dout(Released)
);

always @(posedge clk, posedge rst) begin
    if(rst == 1'b1)
        ack <= 1'b0;
    else if(req == 1'b1)
        ack <= 1'b1;
    else
        ack <= 1'b0;
end

endmodule
