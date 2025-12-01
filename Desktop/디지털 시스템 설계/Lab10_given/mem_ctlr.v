`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2016/11/15 13:57:42
// Design Name: 
// Module Name: mem_clr
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


module mem_ctlr(
        input clk,
        input rst,
        input en,
        input [7:0] din,
        input [1:0] mode,
        output we,
        output [7:0] dout,
        output [18:0] addr
    );
   
   localparam CLEAR = 2'b00, SHIFTR = 2'b01, RG_SHIFTL = 2'b10;  
   reg [1:0] state_reg, state_next;
   reg [18:0] addr_reg, addr_next;
   reg [15:0] dout_reg, dout_next;
   reg we_reg, we_next;
   reg [7:0] din_p, din_n;
   assign dout = dout_reg;
   assign addr = addr_reg;
   assign we = we_reg;
   
   always @(posedge clk or posedge rst)
    if (rst) begin
        state_reg <= 1'b0;
        addr_reg <= 19'h00000;
        we_reg <= 'b0;
        dout_reg <= 8'h00;
        din_p <= 8'h00;
        end
    else    begin
        state_reg <= state_next;
        addr_reg <= addr_next;
        we_reg <= we_next;
        dout_reg <= dout_next;
        din_p <= din_n;
    end
    
       
    
    always @ (addr_reg, we_reg, dout_reg, state_reg, en)begin
        case(state_reg)
            2'b00 :    //idle
                if (en) begin
                        state_next = 2'b01;
                        addr_next = addr_reg;
                        we_next = 1'b0;
                    end
                else    begin
                        state_next = 2'b00;
                        addr_next = addr_reg;
                        we_next = 1'b0;
                end
            2'b01 : //CLEAR
                if (mode == CLEAR) begin    
                    if (addr_reg < 640 * 480) begin 
                            state_next = 2'b01;
                            addr_next = addr_reg + 1'b1;
                            we_next = 1'b1;
                            dout_next = 8'h00;   
                     end 
                    else begin
                            state_next = 2'b00;
                            addr_next = 19'h00000;
                            we_next = 1'b0;
                            dout_next = 8'h00;   
                    end
                end
                else begin
                    state_next = 2'b10;
                    addr_next = addr_reg;
                    we_next = 1'b0;
                end
            2'b10 : //SHIFTR
                 if(mode == SHIFTR) begin
                    if (addr_reg < 640 * 480) begin 
                         if(!we_reg) begin 
                             state_next = 2'b10;
                             addr_next = addr_reg;
                             we_next = 1'b1;
                             dout_next = din_p;
                         end 
                         else begin 
                             state_next = 2'b10;
                             addr_next = addr_reg + 1'b1;
                             we_next = 1'b0;
                             din_n = din;
                         end  
                      end
                     else begin
                         state_next = 2'b00;
                         addr_next = 19'h00000;
                         we_next = 1'b0;
                         dout_next = 8'h00;
                            
                     end
                 end
                 else begin
                    state_next = 2'b11;
                    addr_next = 19'h4AFFF; //640*480 - 1
                    we_next = 1'b0;
                    dout_next = 8'h00;
                    din_n = 8'h00;
                 end
         
              2'b11 : //RG_SHIFTL
                 if(mode == RG_SHIFTL) begin
                    if (addr_reg > 0) begin 
                         if(we_reg) begin
                             state_next = 2'b11;
                             addr_next = addr_reg - 1'b1;
                             we_next = 1'b0;
                             din_n = din;
                         end 
                         else begin
                             state_next = 2'b11;
                             addr_next = addr_reg;
                             we_next = 1'b1;
                             dout_next = {din_p[7:6], din_p[2:0], din_p[5:3]}; // BGR -> BRG
                         end  
                      end
                     else begin
                         state_next = 2'b00;
                         addr_next = 19'h00000;
                         we_next = 1'b0;
                         dout_next = 8'h00;   
                     end
                 end
                 else begin
                    state_next = 2'b00;
                    addr_next = 19'h00000;
                    we_next = 1'b0;
                    dout_next = 8'h00;
                 end
              default:
                begin
                  state_next = 2'b00;
                  addr_next = 19'h00000;
                  we_next = 1'b0;
                  dout_next = 8'h00;
               end
        endcase
     end
    
endmodule
