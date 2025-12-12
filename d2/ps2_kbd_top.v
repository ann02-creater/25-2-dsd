`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: ps2_kbd_top.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원 (based on lab material)
//
// Description:
//   PS2 키보드 최상위 모듈. ps2_kbd_new와 debounce_pulse를 통합.
//   KeyPressed: 키가 눌릴 때 1클럭 펄스 (숫자 입력용)
//   Released: 키가 떨어질 때 1클럭 펄스
//
// Change History:
//   2024.12.12 - KeyPressed 출력 추가
//////////////////////////////////////////////////////////////////////////////////

module ps2_kbd_top(
    input clk,
    input rst,
    input ps2clk,
    input ps2data,
    output [7:0] scancode,
    output KeyPressed,       // 키 눌림 (falling edge of released)
    output Released,         // 키 떨어짐 (rising edge of released)
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

// Rising edge: 키 떨어짐
debounce_pulse pulse_released (
    .clk(clk), 
    .rst(rst), 
    .Din(released_out), 
    .Dout(Released)
);

// Falling edge: 키 눌림 (released_out이 1→0)
reg released_d;
always @(posedge clk) begin
    if (rst)
        released_d <= 1'b1;
    else
        released_d <= released_out;
end
assign KeyPressed = released_d & ~released_out;  // Falling edge detection

always @(posedge clk, posedge rst) begin
    if(rst == 1'b1)
        ack <= 1'b0;
    else if(req == 1'b1)
        ack <= 1'b1;
    else
        ack <= 1'b0;
end

endmodule

