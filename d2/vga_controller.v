`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: vga_controller.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
// 
// Description:
//   640x480 @ 60Hz VGA 타이밍 컨트롤러.
//   100MHz 입력 클럭을 25MHz 픽셀 클럭으로 분주하여 사용.
//   
// VGA Timing (640x480 @ 60Hz):
//   Pixel clock: 25.175 MHz (약 25 MHz)
//   Horizontal: 640 visible + 16 front + 96 sync + 48 back = 800 total
//   Vertical:   480 visible + 10 front + 2 sync + 33 back = 525 total
//
// Reference: 수업 자료 VGA_controller.v를 기반으로 수정
//
// Change History:
//   2024.12.11 - Initial creation
//////////////////////////////////////////////////////////////////////////////////

module vga_controller (
    input wire clk,           // 100 MHz 시스템 클럭
    input wire reset,
    
    output wire hsync,        // Horizontal sync (active low)
    output wire vsync,        // Vertical sync (active low)
    output wire video_on,     // 화면 표시 영역인지 여부
    output wire pixel_clk,    // 25 MHz 픽셀 클럭 (또는 strobe)
    output wire [9:0] pixel_x, // 현재 X 좌표 (0-799)
    output wire [9:0] pixel_y  // 현재 Y 좌표 (0-524)
);

    // =========================================================================
    // VGA 타이밍 파라미터 (640x480 @ 60Hz)
    // =========================================================================
    localparam HD = 640;  // Horizontal display area
    localparam HF = 16;   // Horizontal front porch
    localparam HS = 96;   // Horizontal sync pulse width
    localparam HB = 48;   // Horizontal back porch
    localparam HTOTAL = HD + HF + HS + HB;  // 800
    
    localparam VD = 480;  // Vertical display area
    localparam VF = 10;   // Vertical front porch
    localparam VS = 2;    // Vertical sync pulse width
    localparam VB = 33;   // Vertical back porch
    localparam VTOTAL = VD + VF + VS + VB;  // 525
    
    // =========================================================================
    // 25 MHz 픽셀 클럭 생성 (100 MHz / 4 = 25 MHz)
    // =========================================================================
    reg [1:0] clk_div;
    
    always @(posedge clk) begin
        if (reset)
            clk_div <= 2'b0;
        else
            clk_div <= clk_div + 1'b1;
    end
    
    assign pixel_clk = (clk_div == 2'b11);  // 매 4 클럭마다 1 펄스
    
    // =========================================================================
    // Horizontal Counter (X 좌표)
    // =========================================================================
    reg [9:0] h_count;
    wire h_end = (h_count == HTOTAL - 1);
    
    always @(posedge clk) begin
        if (reset)
            h_count <= 10'd0;
        else if (pixel_clk) begin
            if (h_end)
                h_count <= 10'd0;
            else
                h_count <= h_count + 1'b1;
        end
    end
    
    // =========================================================================
    // Vertical Counter (Y 좌표)
    // =========================================================================
    reg [9:0] v_count;
    wire v_end = (v_count == VTOTAL - 1);
    
    always @(posedge clk) begin
        if (reset)
            v_count <= 10'd0;
        else if (pixel_clk && h_end) begin
            if (v_end)
                v_count <= 10'd0;
            else
                v_count <= v_count + 1'b1;
        end
    end
    
    // =========================================================================
    // Sync 신호 생성 (Active Low)
    // =========================================================================
    // HSYNC: HD+HF 부터 HD+HF+HS-1 까지 LOW
    // VSYNC: VD+VF 부터 VD+VF+VS-1 까지 LOW
    
    reg hsync_reg, vsync_reg;
    
    always @(posedge clk) begin
        if (reset) begin
            hsync_reg <= 1'b1;
            vsync_reg <= 1'b1;
        end
        else if (pixel_clk) begin
            hsync_reg <= ~((h_count >= HD + HF) && (h_count < HD + HF + HS));
            vsync_reg <= ~((v_count >= VD + VF) && (v_count < VD + VF + VS));
        end
    end
    
    assign hsync = hsync_reg;
    assign vsync = vsync_reg;
    
    // =========================================================================
    // Video On 신호 (화면 표시 영역)
    // =========================================================================
    reg video_on_reg;
    
    always @(posedge clk) begin
        if (reset)
            video_on_reg <= 1'b0;
        else if (pixel_clk)
            video_on_reg <= (h_count < HD) && (v_count < VD);
    end
    
    assign video_on = video_on_reg;
    
    // =========================================================================
    // 출력 좌표
    // =========================================================================
    assign pixel_x = h_count;
    assign pixel_y = v_count;

endmodule
