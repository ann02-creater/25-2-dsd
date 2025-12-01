`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Cheolho Kang
// 
// Create Date:    12:44:37 11/29/2014 
// Design Name: 
// Module Name:    vga_disp 
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
module vga_display(
    input wire clk,
    input wire clk_en,
    input wire rst,
    output reg [9:0] hcnt,
    output reg [9:0] vcnt,
    output reg hsyncb,
    output reg vsyncb,
	output wire detect_neg_vsyncb,
	output reg video_off,
    input wire en,
	input wire en2
    );

reg vsyncb_1, vsyncb_2, vsyncb_3, vsyncb_4, vsyncb_5;
reg hsyncb_1, hsyncb_2, hsyncb_3, hsyncb_4, hsyncb_5;

localparam [9:0] SCAN_LINE_TIME_MAX_TIC = 799;
localparam [9:0] LINE_NUM_LIM = 524;

localparam [9:0] ACTIVE_VIDEO_TIC = 640;
localparam [9:0] FRONT_PORCH_TIC = 16;
localparam [9:0] HRZ_SYNC_TIC = 96;
localparam [9:0] BACK_PORCH_TIC = 48;

localparam [9:0] ACTIVE_VERT_LINE = 480;
localparam [9:0] FRONT_PORCH_LINE = 10;
localparam [9:0] VERT_SYNC_LINE = 2;
localparam [9:0] BACK_PORCH_LINE = 29;

reg buf_hsyncb, buf_vsyncb;

always @(posedge clk, posedge rst)
	if (rst)
		hcnt <= 'b0;
	else if (clk_en) begin
        if(en2 == 1) begin
            if (hcnt < SCAN_LINE_TIME_MAX_TIC && en == 'b1)		// 799-48
                hcnt <= hcnt + 1;
            else 
                hcnt <='b0;
        end
	end
always @( posedge clk, posedge rst)
	if (rst)
		buf_hsyncb <= 'b1;
	else if(clk_en && en2)
		buf_hsyncb <= hsyncb;

// hsyncb의 rising edge를 detect한다.		
//assign detect_hsyncb = ( hsyncb & ~buf_hsyncb);

always @(posedge clk, posedge rst)
	if (rst)
		vcnt <= 'b0;
	else if (clk_en) begin
           if(en2 == 1) begin
            if (hcnt == 799)
                if ( vcnt < LINE_NUM_LIM && en == 'b1)
                    vcnt <= vcnt + 1;
                else
                    vcnt <= 'b0;
            end	
        end
//  for centering the horiz position hsyncb should be asserted at the time 
//   +   640 <=  real display period
//   +   16 <= FRONT_PORCH_TIC
//   = 640 + 16 = 656

always @(posedge clk, posedge rst)
	if (rst) 
		hsyncb <= 1;
	else if (clk_en) begin
        if(en2)
            if ((hcnt > 656+48 ) && (hcnt < 656+48 + HRZ_SYNC_TIC))	//96
                hsyncb <= 'b0;
            else
                hsyncb <= 'b1;
    end
// for centering the vertical  position hsyncb should be asserted at the time 
  //   +   480 <=  real  display period
  //   +   10 <= FRONT_PORCH_LINE
  //   =   480 + 10 = 490 line
  
always @(posedge clk, posedge rst)
	if (rst) 
		vsyncb <= 1;
	else if (clk_en) begin
	   if ((vcnt > 489) && (vcnt < 490 + VERT_SYNC_LINE))//492
		  vsyncb <= 'b0;
	   else
		  vsyncb <= 'b1;
    end
always @(posedge clk, posedge rst) begin
	if(rst)
		video_off <= 1;
	else if (clk_en) begin
	   if(vcnt > 479 && vcnt < LINE_NUM_LIM)
		  video_off <= 1;
    	else
	       	video_off <= 0;
    end
end

always @(posedge clk, posedge rst)
	if (rst)
		buf_vsyncb <= 'b0;
	else if(clk_en & en2)
		buf_vsyncb <= ~vsyncb;
		
assign detect_neg_vsyncb = (~buf_vsyncb & ~vsyncb);

endmodule
