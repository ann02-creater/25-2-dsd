`timescale 1ns / 1ps
module Four_Digit_Seven_Segment_Driver_2 (
    input clk,
    input [12:0] num,
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
        // ★★★ 나눗셈 제거하고 하위 4비트씩 잘라서 보여주도록 수정 ★★★
        case(LED_activating_counter)
            2'b00: begin
                Anode = 4'b0111;
                LED_BCD = num[12:12]; // 임시 (맨 앞자리)
            end
            2'b01: begin
                Anode = 4'b1011;
                LED_BCD = num[11:8];  // 16진수 표현처럼 변경
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

    // (7-segment 디코더 부분은 그대로 유지)
    always @(*) begin
        case(LED_BCD)
            4'b0000: LED_out = 7'b0000001; // "0"
            4'b0001: LED_out = 7'b1001111; // "1"
            4'b0010: LED_out = 7'b0010010; // "2"
            4'b0011: LED_out = 7'b0000110; // "3"
            4'b0100: LED_out = 7'b1001100; // "4"
            4'b0101: LED_out = 7'b0100100; // "5"
            4'b0110: LED_out = 7'b0100000; // "6"
            4'b0111: LED_out = 7'b0001111; // "7"
            4'b1000: LED_out = 7'b0000000; // "8"
            4'b1001: LED_out = 7'b0000100; // "9"
            4'b1010: LED_out = 7'b1111110; // A
            4'b1011: LED_out = 7'b0110000; // b
            4'b1100: LED_out = 7'b0110001; // C
            4'b1101: LED_out = 7'b1000010; // d
            4'b1110: LED_out = 7'b0110000; // E
            4'b1111: LED_out = 7'b0111000; // F
            default: LED_out = 7'b0000001; 
        endcase
    end
endmodule