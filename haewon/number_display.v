`timescale 1ns / 1ps
module Four_Digit_Seven_Segment_Driver_2 (
    input clk,
    input [15:0] num,
    output reg [3:0] Anode,
    output reg [6:0] LED_out
 );
    reg [3:0] LED_BCD;
    reg [19:0] refresh_counter = 0; 
    wire [1:0] LED_activating_counter;
 
    always @(posedge clk) begin
        refresh_counter <= refresh_counter + 1;
    end

    assign LED_activating_counter = refresh_counter[19:18];

    always @(*) begin
        // ?쁾?쁾?쁾 ?굹?닓?뀍 ?젣嫄고븯怨? ?븯?쐞 4鍮꾪듃?뵫 ?옒?씪?꽌 蹂댁뿬二쇰룄濡? ?닔?젙 ?쁾?쁾?쁾
        case(LED_activating_counter)
            2'b00: begin
                Anode = 4'b0111;
                LED_BCD = num[15:12]; // ?엫?떆 (留? ?븵?옄由?)
            end
            2'b01: begin
                Anode = 4'b1011;
                LED_BCD = num[11:8];  // 16吏꾩닔 ?몴?쁽泥섎읆 蹂?寃?
            end
            2'b10: begin
                Anode = 4'b1101;
                LED_BCD = num[7:4];
            end
            2'b11: begin
                Anode = 4'b1110;
                LED_BCD = num[3:0];
            end
        endcase
    end

    always @(*) begin
        case(LED_BCD)
            4'b0000: LED_out = 7'b1000000; // "0" : a,b,c,d,e,f ON, g OFF
            4'b0001: LED_out = 7'b1111001; // "1" : b,c ON
            4'b0010: LED_out = 7'b0100100; // "2"
            4'b0011: LED_out = 7'b0110000; // "3"
            4'b0100: LED_out = 7'b0011001; // "4"
            4'b0101: LED_out = 7'b0010010; // "5"
            4'b0110: LED_out = 7'b0000010; // "6"
            4'b0111: LED_out = 7'b1111000; // "7"
            4'b1000: LED_out = 7'b0000000; // "8"
            4'b1001: LED_out = 7'b0010000; // "9"
    
            4'b1010: LED_out = 7'b0001000; // "A"
            4'b1011: LED_out = 7'b0000011; // "b"
            4'b1100: LED_out = 7'b1000110; // "C"
            4'b1101: LED_out = 7'b0100001; // "d"
            4'b1110: LED_out = 7'b0000110; // "E"
            4'b1111: LED_out = 7'b0001110; // "F"
            default: LED_out = 7'b1111111; 
        endcase
    end
endmodule