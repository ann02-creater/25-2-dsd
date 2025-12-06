`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: seven_segment_8_driver
// Description: 8-digit 7-segment display driver with time-multiplexing
//              Displays 8 individual segments with refresh
//////////////////////////////////////////////////////////////////////////////////

module seven_segment_8_driver(
    input clk,
    input rst,
    input [6:0] seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7, // Individual segment patterns
    output reg [6:0] seg_out,   // 7-segment cathode outputs (active low)
    output reg [7:0] seg_sel    // Anode select (active low)
);

    // Refresh counter for multiplexing
    reg [19:0] refresh_counter;
    wire [2:0] active_digit;

    always @(posedge clk) begin
        if (rst)
            refresh_counter <= 0;
        else
            refresh_counter <= refresh_counter + 1;
    end

    // Select active digit (slower refresh for 8 digits)
    // @ 50MHz: refresh_counter[19:17] changes every 2^17 = 131K cycles
    // Total refresh rate: 50MHz / 2^17 / 8 digits = ~47Hz per digit (376Hz total)
    assign active_digit = refresh_counter[19:17];
    
    // Multiplex: select which anode to activate and which segment pattern to display
    always @(*) begin
        // Default: all off
        seg_sel = 8'b11111111;
        seg_out = 7'b1111111;
        
        case (active_digit)
            3'd0: begin
                seg_sel = 8'b11111110; // AN0 active
                seg_out = seg0;
            end
            3'd1: begin
                seg_sel = 8'b11111101; // AN1 active
                seg_out = seg1;
            end
            3'd2: begin
                seg_sel = 8'b11111011; // AN2 active
                seg_out = seg2;
            end
            3'd3: begin
                seg_sel = 8'b11110111; // AN3 active
                seg_out = seg3;
            end
            3'd4: begin
                seg_sel = 8'b11101111; // AN4 active
                seg_out = seg4;
            end
            3'd5: begin
                seg_sel = 8'b11011111; // AN5 active
                seg_out = seg5;
            end
            3'd6: begin
                seg_sel = 8'b10111111; // AN6 active
                seg_out = seg6;
            end
            3'd7: begin
                seg_sel = 8'b01111111; // AN7 active
                seg_out = seg7;
            end
        endcase
    end

endmodule
