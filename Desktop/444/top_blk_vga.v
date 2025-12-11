`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2017/02/01 16:02:19
// Design Name: 
// Module Name: top_blk_vga
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_blk_vga(
    
    //crystal
    input            clk,            // Clock input
    //buttons  
    input            rst,            // Active HIGH reset
    input            enable_memw,    // Mem Write enable -> port A enable
    input            enable_vga,     // VGA enable
    //switch
    input     [3:0]   sw,
    // PS/2 keyboard
    input            ps2_clk,
    input            ps2_data,
    // VGA pins
    output    [7:0]   rgb,
    output            hsyncb,
    output            vsyncb    
    );
wire clk_100, clk_50;
wire enable_memw_tick;
wire enable_vga_tg;
wire [18:0]ADDR_vga2mem, ADDR_ctrl2mem;
wire [7:0] D_mem2vga, D_mem2ctrl, D_ctrl2mem;
wire wea;
wire [7:0] ps2_code;
wire ps2_code_ready;
wire [3:0] y_offset;
wire [1:0] mode = 2'b00;  // Default: CLEAR mode (메모리 초기화 모드)

// enable_vga_tg는 debounce_vga 모듈의 toggle 출력으로 사용됨
//clock core 
clk_wiz_0 clk_core (
    .clk_in1(clk),      
    // Clock out ports
    .clk_out1(clk_100),     // 100MHz output clk
    .clk_out2(clk_50),      //  50MHz output clk
    //control
    .reset(rst)             // input reset
    );       
//frame_buffer. simple dual block ram
// port A for writing port B for reading mainly    
blk_mem_gen_0 frame_buffer (
    .clka(clk_100),    // input wire clka
    .wea(wea),      // input wire [0 : 0] wea
    .addra(ADDR_ctrl2mem),  // input wire [18 : 0] addra
    .dina(D_ctrl2mem),    // input wire [7 : 0] dina
    .douta(D_mem2ctrl),  // output wire [7 : 0] douta
    .clkb(clk_50),    // input wire clkb
    .web(1'b0),      // input wire [0 : 0] web
    .addrb(ADDR_vga2mem),  // input wire [18 : 0] addrb
    .dinb(8'h00),    // input wire [7 : 0] dinb
    .doutb(D_mem2vga)  // output wire [7 : 0] doutb
    );    
// PS/2 화살표 키 기반 Y-Offset 컨트롤러
// Up arrow (↑): 위로 이동
// Down arrow (↓): 아래로 이동
ps2_arrow_yoffset_top #(
    .MAX_STEP(4'd14)  // 14 * 32 = 448 pixels
) kb_arrow_ctrl (
    .clk(clk_50),
    .rst(rst),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .y_offset(y_offset),
    .debug_scancode(ps2_code),
    .debug_ready(ps2_code_ready)
    );
TOP_VGA vga(
    .clk(clk_50),
    .clk_en(enable_vga_tg),
    .y_offset(y_offset), 
    .rst(rst),
    .din(D_mem2vga),
    .addr(ADDR_vga2mem),
    .rgb(rgb),
    .hsyncb(hsyncb),
    .vsyncb(vsyncb)
    );
debounce debounce_vga(
    .clk(clk_100),
    .rst(rst),
    .din(enable_vga),
    .tick(),
    .toggle(enable_vga_tg)
    );
debounce debounce_memw(
    .clk(clk_100),
    .rst(rst),
    .din(enable_memw),
    .tick(enable_memw_tick),
    .toggle()
    );
mem_ctlr mem_ctrl(
    .clk(clk),
    .rst(rst),
    .en(enable_memw_tick),
    .din(D_mem2ctrl),
    .mode(mode),
    .we(wea),
    .dout(D_ctrl2mem),
    .addr(ADDR_ctrl2mem)
);
endmodule
