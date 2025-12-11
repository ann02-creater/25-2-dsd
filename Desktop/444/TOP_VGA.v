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
module TOP_VGA (
    input wire clk,
    input wire clk_en,
    input wire rst,
    
    /* Block ram interface */
    input wire [3:0] y_offset,
    input wire [7:0] din,
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
wire [7:0] Rdata;
wire [18:0] raddr;
wire [3:0] XY = 4'b0000;  // Fixed: was 3'b000
wire [3:0] YY;
assign YY = y_offset;
assign Xoffset = {XY, 6'd0};  // Fixed: was 6'd00
assign Yoffset = {YY, 5'd0};  // Fixed: was 5'd00


localparam [9:0] XRES = 10'd640;
localparam [8:0] YRES = 9'd480;


assign Rdata = din;
assign addr = raddr;

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
