`timescale 1ns / 1ps

// Debounce module - Fixed gated clock issue
// Changed toggle logic from using 'tick' as clock to synchronous logic
module debounce(
    input clk,
    input rst,
    input din,
    output tick,
    output reg toggle
    );

reg d1, d2;
wire tick_internal;

always @(posedge clk or posedge rst)
    if( rst ) begin
       d1 <= 1'b0;
       d2 <= 1'b0;
    end
    else begin
       d1 <= din;
       d2 <= d1;
    end

assign tick_internal = d1 & ~d2;
assign tick = tick_internal;
 
// Fixed: Use synchronous logic instead of gated clock
always @(posedge clk or posedge rst)
   if( rst )
       toggle <= 1'b0;
   else if ( tick_internal )
       toggle <= ~toggle;

endmodule
