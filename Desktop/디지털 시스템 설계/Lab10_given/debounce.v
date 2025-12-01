`timescale 1ns / 1ps


module debounce(
    input clk,
    input rst,
    input din,
    output tick,
    output reg toggle
    );

reg d1, d2;
always @(posedge clk, posedge rst)
    if( rst ) begin
       d1 <= 'b0;
       d2 <= 'b0;
    end
    else begin
       d1 <= din;
       d2 <= d1;
    end

assign tick = d1 & ~ d2;
 
always @ (posedge rst, posedge tick)
   if( rst )
       toggle <= 'b0;
   else if ( tick )
       toggle <= ~ toggle;

endmodule
