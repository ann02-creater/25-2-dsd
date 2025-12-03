`timescale 1ns / 1ps
/*******************************************************************
*
* Module: ripple.v
* Project: RISC-V FPGA Implementation and Testing 
* Author: 
* Ahmed Ibrahim  ahmeddibrahim@aucegypt.edu
* Abd El-Salam   solomspd@aucegypt.edu
* Andrew Kamal   andrewk.kamal@aucegypt.edu
* Rinal Mohamed  rinalmohamed@aucegypt.edu
* Description: This module just creates one instance of a *ripple to be used calculate the ripple carry adder of an n-bit adder and provides the output and the most significant bit. 
*
* Change history: 09/17/2019 03:07:59 PM - Module created by Abd *El-Salam in the lab
* 10/24/19 � Ahmed, Andrew, Abd El-Salam, and Rinal worked on the *module to make it compatible with the other modules modified in *the sources files
* 10/29/19- Ahmed, Andrew, Abd El-Salam, and Rinal made the final modificaions to the module
*
**********************************************************************/

module ripple#(parameter n = 31)(input [n:0]a, input [n:0]b, output [n:0]out, output cout);
    // 합성 최적화: ripple carry adder 대신 + 연산자 사용
    // Vivado가 자동으로 최적의 가산기 구조로 합성함
    assign {cout, out} = a + b;
endmodule
