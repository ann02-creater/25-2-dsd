`timescale 1ns / 1ps
/*******************************************************************

*

* Module: shifter.v

* Project: RISC-V FPGA Implementation and Testing 

* Author: 

* Ahmed Ibrahim  ahmeddibrahim@aucegypt.edu

* Abd El-Salam   solomspd@aucegypt.edu

* Andrew Kamal   andrewk.kamal@aucegypt.edu

* Rinal Mohamed  rinalmohamed@aucegypt.edu

* Description: This module is just a forwarding unit that is responsible for handling data hazards.

* Change history: 10/11/2019 module added to the project 
*
**********************************************************************/


module Forward_Unit(
input EX_MEM_RegWrite, MEM_WB_RegWrite,
input [4:0 ]EX_MEM_RegisterRd, ID_EX_RegisterRs1,ID_EX_RegisterRs2,MEM_WB_RegisterRd,
output reg [1:0] forwardA, forwardB
    );
    
 // FIXED: forwardA and forwardB must be evaluated independently!
 // Previous bug: They were in the same if-else chain, causing mutual exclusion
 // This would fail when both Rs1 and Rs2 need forwarding simultaneously
 always @(*) begin
     // Forward A logic (independent evaluation for Rs1)
     if (EX_MEM_RegWrite && (EX_MEM_RegisterRd != 0) && (EX_MEM_RegisterRd == ID_EX_RegisterRs1))
         forwardA = 2'b10;  // Forward from EX/MEM stage
     else if (MEM_WB_RegWrite && (MEM_WB_RegisterRd != 0) && (MEM_WB_RegisterRd == ID_EX_RegisterRs1))
         forwardA = 2'b01;  // Forward from MEM/WB stage
     else
         forwardA = 2'b00;  // No forwarding

     // Forward B logic (independent evaluation for Rs2)
     if (EX_MEM_RegWrite && (EX_MEM_RegisterRd != 0) && (EX_MEM_RegisterRd == ID_EX_RegisterRs2))
         forwardB = 2'b10;  // Forward from EX/MEM stage
     else if (MEM_WB_RegWrite && (MEM_WB_RegisterRd != 0) && (MEM_WB_RegisterRd == ID_EX_RegisterRs2))
         forwardB = 2'b01;  // Forward from MEM/WB stage
     else
         forwardB = 2'b00;  // No forwarding
 end   
    
    
    
    
    
endmodule
