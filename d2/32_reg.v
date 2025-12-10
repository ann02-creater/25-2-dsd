`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: register
// Description: Parameterized Register with Synchronous Reset
//              - Fixes DRC REQP-1839 (Async Control Check) for BRAM usage
//////////////////////////////////////////////////////////////////////////////////

module register #(parameter n = 32) (
    input clk,
    input [n-1:0] in,
    input rst,
    input load,
    output reg [n-1:0] out
);

    always @(posedge clk) begin
        if (rst) begin
            out <= {n{1'b0}};
        end else if (load) begin
            out <= in;
        end
    end

endmodule
