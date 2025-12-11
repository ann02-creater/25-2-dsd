`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Cheolho Kang
// 
// Create Date:    12:44:02 11/29/2014 
// Design Name: 
// Module Name:    VGA_module 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module VGA_module(
    input wire clk,
    input wire clk_en,
    input wire rst,
	input wire [7:0] data,
	input wire [9:0] Xoffset,
	input wire [8:0] Yoffset,
    input wire [9:0] imageWidth,
    input wire [8:0] imageHeight, 
	output wire hsyncb,
	output wire vsyncb,
	output wire [18:0] addr,
	output wire video_off,
    output wire [7:0] rgb
    );
	
wire [9:0] hcnt, vcnt;	

wire en25Mhz;
wire detect_neg_vsyncb;

clk_gen_25Mhz en_25MHz (
    .clk50Mhz(clk),
    .clk_en(clk_en), 
    .rst(rst), 
    .clk25Mhz(en25Mhz)
    );

vga_display VGAdisp (
    .clk(clk), 
    .clk_en(clk_en),
    .rst(rst), 
    .hcnt(hcnt), 
    .vcnt(vcnt), 
    .hsyncb(hsyncb), 
    .vsyncb(vsyncb),
	.detect_neg_vsyncb(detect_neg_vsyncb),
    .en(1'b1),
	.video_off(video_off),
	.en2(en25Mhz)
    );

vga_data VGAdata (
    .clk(clk),
    .clk_en(clk_en), 
    .rst(rst), 
    .hcnt(hcnt), 
    .vcnt(vcnt), 
	.Xposition1(Xoffset),
	.Yposition1(Yoffset),
	.imageWidth(imageWidth), 
    .imageHeight(imageHeight), 
    .data(data), 
    .addr(addr),
	.detect_neg_vsyncb(detect_neg_vsyncb),
    .rgb(rgb)
    );
	 
endmodule
