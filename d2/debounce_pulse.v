`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: debounce_pulse.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원 (based on lab material)
//
// Description:
//   입력 신호의 rising edge를 감지하여 1 클럭 펄스 출력.
//   키보드 입력의 edge detection에 사용.
//
// Change History:
//   2024.12.11 - Lab 자료 기반으로 통합
//////////////////////////////////////////////////////////////////////////////////

module debounce_pulse(
    input wire clk,
    input wire rst,
    input wire Din,
    output wire Dout
);

wire A;
reg B, C;

assign A = Din;

always @(posedge clk) begin
    if(rst == 1) begin
        B <= 0;
        C <= 0;
    end
    else begin
        B <= A;
        C <= B;
    end
end

// Rising edge detection: ~C & B
assign Dout = (~C & B);

endmodule
