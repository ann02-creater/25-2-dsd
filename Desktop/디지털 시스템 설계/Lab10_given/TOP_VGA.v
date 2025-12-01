`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Cheolho Kang
// 
// Create Date:    12:45:11 11/29/2014 
// Design Name: 
// Module Name:    TOP_VGA 
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
module TOP_VGA #(
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 19
 )(
    
	input wire clk,
	input wire clk_en,
	input wire rst,
	
	/* Block ram interface */
    input wire [2:0] y_offset_sw,
	inout wire [7:0] din,
    output wire WES,
    output reg [7:0] dout,
    output wire [18:0] addr,
    
    /* VGA interface*/
    output wire [7:0] rgb,
    output wire hsyncb,
	output wire vsyncb

    );
    
/* display config */
wire [9:0] Xoffset;
wire [8:0] Yoffset;
wire video_off;


/* sample ram */
wire [7:0] Wdata;
wire [18:0] Waddr;
wire [7:0] Rdata;
wire [18:0] raddr;
//wire [3:0] XY = 3'b010;
wire [3:0] XY = 3'b000;
wire [3:0] YY;
assign YY = y_offset_sw;
assign Xoffset = {XY_fixed, 6'd0}; 
assign Yoffset = {YY, 5'd0};  




assign Xoffset = {XY,6'd00};
assign Yoffset = {XY,5'd00};


localparam XRES = 640;
localparam YRES = 480;


assign Rdata = din;
assign addr = raddr;
assign WES = 1'b0;

VGA_module vga (
    .clk(clk), 
    .clk_en(clk_en),
    .rst(rst), 
    .data(Rdata), 
    .hsyncb(hsyncb), 
    .vsyncb(vsyncb), 
	.Xoffset(Xoffset),
	.Yoffset(Yoffset),
	.imageWidth(XRES), 
    .imageHeight(YRES),
    .addr(raddr), 
	.video_off(video_off),
    .rgb(rgb)
    );
	 


endmodule
