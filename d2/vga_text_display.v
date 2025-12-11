`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: vga_text_display.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   VGA 화면에 "ODD" 또는 "EVEN" 텍스트를 표시하는 모듈.
//   ROM 기반 폰트 대신 하드코딩된 픽셀 패턴을 사용하여 간단하게 구현.
//   
//   화면 중앙 (약 270,200) 위치에 큰 글씨로 결과 표시.
//   글자 크기: 약 100x60 픽셀 (가독성을 위해 크게)
//
// Interface with CPU (Memory-Mapped I/O):
//   0x40000000 (WRITE): 
//     0 = 화면 클리어 (아무것도 표시 안 함)
//     1 = "ODD" 표시
//     2 = "EVEN" 표시
//
// VGA Timing: 640x480 @ 60Hz, 25MHz pixel clock
//
// Change History:
//   2024.12.11 - Initial creation (Option B: Hardcoded pixel pattern)
//////////////////////////////////////////////////////////////////////////////////

module vga_text_display(
    input wire clk,           // 25MHz pixel clock
    input wire rst,
    
    // VGA 좌표 입력 (from VGA_controller)
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire video_on,
    
    // CPU로부터의 결과 입력 (MMIO)
    input wire [1:0] result,  // 00=none, 01=odd, 10=even
    
    // VGA 색상 출력
    output reg [3:0] vga_r,
    output reg [3:0] vga_g,
    output reg [3:0] vga_b
);

    // =========================================================================
    // 텍스트 표시 영역 정의 (화면 중앙)
    // =========================================================================
    // 640x480 화면의 중앙에 텍스트 배치
    // "ODD"  = 3글자, "EVEN" = 4글자
    
    localparam TEXT_Y_START = 200;  // 텍스트 시작 Y 좌표
    localparam TEXT_Y_END   = 280;  // 텍스트 끝 Y 좌표 (높이 80px)
    
    // ODD 표시 영역 (3글자 × 약 40px = 120px, 중앙 정렬)
    localparam ODD_X_START  = 260;  // (640-120)/2 = 260
    localparam ODD_X_END    = 380;
    
    // EVEN 표시 영역 (4글자 × 약 40px = 160px, 중앙 정렬)
    localparam EVEN_X_START = 240;  // (640-160)/2 = 240
    localparam EVEN_X_END   = 400;
    
    // 글자 너비
    localparam CHAR_WIDTH = 40;
    localparam CHAR_HEIGHT = 80;
    
    // =========================================================================
    // "O" 문자 패턴 (40x80 -> 8x16 패턴을 5배 확대)
    // =========================================================================
    // 기본 8x16 패턴을 정의하고, 좌표를 5로 나눠서 참조
    
    wire [2:0] char_col;  // 0-7 (8 columns in pattern)
    wire [3:0] char_row;  // 0-15 (16 rows in pattern)
    
    // 현재 픽셀이 텍스트 영역에 있는지
    wire in_text_y = (pixel_y >= TEXT_Y_START) && (pixel_y < TEXT_Y_END);
    
    // "O" 글자 패턴 (8x16 bitmap)
    reg [7:0] char_O [0:15];
    initial begin
        char_O[0]  = 8'b00111100;
        char_O[1]  = 8'b01100110;
        char_O[2]  = 8'b11000011;
        char_O[3]  = 8'b11000011;
        char_O[4]  = 8'b11000011;
        char_O[5]  = 8'b11000011;
        char_O[6]  = 8'b11000011;
        char_O[7]  = 8'b11000011;
        char_O[8]  = 8'b11000011;
        char_O[9]  = 8'b11000011;
        char_O[10] = 8'b11000011;
        char_O[11] = 8'b11000011;
        char_O[12] = 8'b11000011;
        char_O[13] = 8'b11000011;
        char_O[14] = 8'b01100110;
        char_O[15] = 8'b00111100;
    end
    
    // "D" 글자 패턴
    reg [7:0] char_D [0:15];
    initial begin
        char_D[0]  = 8'b11111100;
        char_D[1]  = 8'b11000110;
        char_D[2]  = 8'b11000011;
        char_D[3]  = 8'b11000011;
        char_D[4]  = 8'b11000011;
        char_D[5]  = 8'b11000011;
        char_D[6]  = 8'b11000011;
        char_D[7]  = 8'b11000011;
        char_D[8]  = 8'b11000011;
        char_D[9]  = 8'b11000011;
        char_D[10] = 8'b11000011;
        char_D[11] = 8'b11000011;
        char_D[12] = 8'b11000011;
        char_D[13] = 8'b11000011;
        char_D[14] = 8'b11000110;
        char_D[15] = 8'b11111100;
    end
    
    // "E" 글자 패턴
    reg [7:0] char_E [0:15];
    initial begin
        char_E[0]  = 8'b11111111;
        char_E[1]  = 8'b11000000;
        char_E[2]  = 8'b11000000;
        char_E[3]  = 8'b11000000;
        char_E[4]  = 8'b11000000;
        char_E[5]  = 8'b11000000;
        char_E[6]  = 8'b11111100;
        char_E[7]  = 8'b11111100;
        char_E[8]  = 8'b11000000;
        char_E[9]  = 8'b11000000;
        char_E[10] = 8'b11000000;
        char_E[11] = 8'b11000000;
        char_E[12] = 8'b11000000;
        char_E[13] = 8'b11000000;
        char_E[14] = 8'b11000000;
        char_E[15] = 8'b11111111;
    end
    
    // "V" 글자 패턴
    reg [7:0] char_V [0:15];
    initial begin
        char_V[0]  = 8'b11000011;
        char_V[1]  = 8'b11000011;
        char_V[2]  = 8'b11000011;
        char_V[3]  = 8'b11000011;
        char_V[4]  = 8'b11000011;
        char_V[5]  = 8'b11000011;
        char_V[6]  = 8'b01100110;
        char_V[7]  = 8'b01100110;
        char_V[8]  = 8'b01100110;
        char_V[9]  = 8'b01100110;
        char_V[10] = 8'b00111100;
        char_V[11] = 8'b00111100;
        char_V[12] = 8'b00111100;
        char_V[13] = 8'b00011000;
        char_V[14] = 8'b00011000;
        char_V[15] = 8'b00011000;
    end
    
    // "N" 글자 패턴
    reg [7:0] char_N [0:15];
    initial begin
        char_N[0]  = 8'b11000011;
        char_N[1]  = 8'b11100011;
        char_N[2]  = 8'b11110011;
        char_N[3]  = 8'b11111011;
        char_N[4]  = 8'b11011111;
        char_N[5]  = 8'b11001111;
        char_N[6]  = 8'b11000111;
        char_N[7]  = 8'b11000011;
        char_N[8]  = 8'b11000011;
        char_N[9]  = 8'b11000011;
        char_N[10] = 8'b11000011;
        char_N[11] = 8'b11000011;
        char_N[12] = 8'b11000011;
        char_N[13] = 8'b11000011;
        char_N[14] = 8'b11000011;
        char_N[15] = 8'b11000011;
    end
    
    // =========================================================================
    // 픽셀 값 계산
    // =========================================================================
    
    // 텍스트 내 상대 좌표 (5배 확대를 위해 5로 나눔)
    wire [9:0] rel_x_odd  = pixel_x - ODD_X_START;
    wire [9:0] rel_x_even = pixel_x - EVEN_X_START;
    wire [9:0] rel_y = pixel_y - TEXT_Y_START;
    
    // 패턴 내 좌표 (5배 축소)
    wire [2:0] pattern_x_odd  = rel_x_odd[9:3] % 8;   // 40/5 = 8
    wire [3:0] pattern_y = rel_y[9:3] % 16;           // 80/5 = 16
    
    // 현재 글자 인덱스
    wire [1:0] char_idx_odd  = rel_x_odd / CHAR_WIDTH;  // 0, 1, 2 for O, D, D
    wire [1:0] char_idx_even = rel_x_even / CHAR_WIDTH; // 0, 1, 2, 3 for E, V, E, N
    
    // 글자 내 X 좌표
    wire [9:0] in_char_x_odd  = rel_x_odd % CHAR_WIDTH;
    wire [9:0] in_char_x_even = rel_x_even % CHAR_WIDTH;
    
    // 패턴 좌표 (5배 축소: 40px -> 8 columns)
    wire [2:0] px_odd  = in_char_x_odd / 5;
    wire [2:0] px_even = in_char_x_even / 5;
    wire [3:0] py = rel_y / 5;
    
    // "ODD" 픽셀 값
    reg pixel_odd;
    always @(*) begin
        case (char_idx_odd)
            2'd0: pixel_odd = char_O[py][7 - px_odd];  // 'O'
            2'd1: pixel_odd = char_D[py][7 - px_odd];  // 'D'
            2'd2: pixel_odd = char_D[py][7 - px_odd];  // 'D'
            default: pixel_odd = 1'b0;
        endcase
    end
    
    // "EVEN" 픽셀 값
    reg pixel_even;
    always @(*) begin
        case (char_idx_even)
            2'd0: pixel_even = char_E[py][7 - px_even];  // 'E'
            2'd1: pixel_even = char_V[py][7 - px_even];  // 'V'
            2'd2: pixel_even = char_E[py][7 - px_even];  // 'E'
            2'd3: pixel_even = char_N[py][7 - px_even];  // 'N'
            default: pixel_even = 1'b0;
        endcase
    end
    
    // =========================================================================
    // 최종 색상 출력
    // =========================================================================
    // 배경: 검정, ODD: 녹색, EVEN: 파랑
    
    wire in_odd_area  = in_text_y && (pixel_x >= ODD_X_START)  && (pixel_x < ODD_X_END);
    wire in_even_area = in_text_y && (pixel_x >= EVEN_X_START) && (pixel_x < EVEN_X_END);
    
    always @(posedge clk) begin
        if (rst || !video_on) begin
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end
        else if (result == 2'b01 && in_odd_area && pixel_odd) begin
            // ODD: 녹색 텍스트
            vga_r <= 4'h0;
            vga_g <= 4'hF;
            vga_b <= 4'h0;
        end
        else if (result == 2'b10 && in_even_area && pixel_even) begin
            // EVEN: 파란색 텍스트
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'hF;
        end
        else begin
            // 배경: 검정
            vga_r <= 4'h0;
            vga_g <= 4'h0;
            vga_b <= 4'h0;
        end
    end

endmodule
