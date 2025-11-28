`timescale 1ns / 1ps
/*******************************************************************
*
* Module: register.v
* Project: RISC-V FPGA Implementation and Testing 
* Author: 
* Ahmed Ibrahim  ahmeddibrahim@aucegypt.edu
* Abd El-Salam   solomspd@aucegypt.edu
* Andrew Kamal   andrewk.kamal@aucegypt.edu
* Rinal Mohamed  rinalmohamed@aucegypt.edu
* Description: This module is the core of our implememntaion is it the "top" module that conects everything together
*
* Change history: 09/17/2019 03:07:59 PM - Module created by Abd *El-Salam in the lab
* 17/9/19 - created by Abdelsalam in the lab
* 31/9/19 - adapted datapath to ALU and immediate modules provided by project material. Elaborated and implemented shift module as outlined in provided ALU
* 32/9/19 - fixed zero flag. anded and fixe brnch module
* 26/10/19 - modified control signals according to new control signals.
* 28/10/19 - polish. added jump muxes. lots of bug fixes.
* 29/10/19 - added muxes for break and call. bug fixes.
* 8/11/2019 - implemented the pipelined data path
* 10/11/2019- Tested the pipelined data path and added the *forwarding unit and modified the data path accordingly
* 11/11/2019- Added the unified single ported memory and tested it. Also, tested the whole module
**********************************************************************/
`include "defines.v"

module data_path(
    input clk, input rst, 
    output [31:0]inst_out_ext, output branch_ext, mem_read_ext, mem_to_reg_ext, mem_write_ext, alu_src_ext, reg_write_ext,
    output [1:0]alu_op_ext, output z_flag_ext, output [4:0]alu_ctrl_out_ext, output [31:0]PC_inc_ext, output [31:0]pc_gen_out_ext, output [31:0]PC_ext, output [31:0]PC_in_ext,
    output [31:0]data_read_1_ext, output [31:0]data_read_2_ext, output [31:0]write_data_ext, output [31:0]imm_out_ext, output [31:0]shift_ext, output [31:0]alu_mux_ext,
    output [31:0]alu_out_ext, output [31:0]data_mem_out_ext, output [15:0] led_reg_out
    output [15:0] led_reg_out,

    output [7:0]  uart_tx_data_out,
    output        uart_tx_we_out,
    output        uart_rx_re_out,
    input  [7:0]  uart_rx_data_in,
    input         uart_rx_valid_in,
    input         uart_tx_busy_in
);
 
    wire neg_clk = ~clk;

    wire [31:0] jump_mux; 
    wire [31:0] PC;
    wire [31:0] new_PC_in;
    wire [31:0] final_pc;
    wire [31:0] PC_in;
    wire [31:0] inst_out;
    wire can_branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write, pc_gen_sel, sys;
    wire [1:0] alu_op, rd_sel;
    wire [31:0] write_data;
    wire [31:0] read_data_1;
    wire [31:0] imm_out;
    wire [31:0] read_data_2;
    wire carry_flag, zero_flag, over_flag, sign_flag;
    wire [31:0] alu_mux_out;
    wire [4:0]  alu_ctrl_out;
    wire [31:0] alu_out;
    wire should_branch;
    wire [31:0] data_mem_out;
    wire [31:0] pc_gen_out;
    wire dummy_carry;
    wire [31:0] pc_gen_in;
    wire [31:0] pc_inc_out;
    wire dummy_carry_2;
    wire [1:0] forwardA, forwardB;
    wire [31:0] inputA, inputB; 
    wire stall;

    // ----------------------------------------------------------------------
    // 1. IF/ID Pipeline Register (Stall Logic: Freeze)
    // ----------------------------------------------------------------------
    
    // 파이프라인 레지스터 출력 와이어 선언
    wire [31:0] IF_ID_PC, IF_ID_Inst;
   
    // IF-ID 레지스터: Stall 신호(Hazard Unit에서 옴)가 0일 때만 업데이트
    // Stall이 1이면 Enable이 0이 되어 이전 값을 유지함 (Freeze)
    register #(64) IF_ID (
        clk,
        {PC, inst_out},        // 입력
        rst,
        ~stall,                // Enable (Stall일 때 멈춤)
        {IF_ID_PC, IF_ID_Inst} // 출력
    );

    // ----------------------------------------------------------------------
    // 2. ID/EX Pipeline Register (Stall Logic: Bubble)
    // ----------------------------------------------------------------------
    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
    wire ID_EX_can_branch, ID_EX_mem_read, ID_EX_mem_to_reg, ID_EX_mem_write, ID_EX_alu_src, ID_EX_reg_write, ID_EX_pc_gen_sel, ID_EX_sys;
    wire [1:0] ID_EX_alu_op, ID_EX_rd_sel; 
    wire [3:0] ID_EX_Func;
    wire [4:0] ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd;
    wire ID_Ex_Func25;

    // ★ Stall 발생 시 ID/EX로 넘어가는 제어 신호를 0으로 만듦 (거품 주입) ★
    wire real_reg_write  = stall ? 1'b0 : reg_write;
    wire real_mem_to_reg = stall ? 1'b0 : mem_to_reg;
    wire real_mem_read   = stall ? 1'b0 : mem_read;
    wire real_mem_write  = stall ? 1'b0 : mem_write;
    wire real_can_branch = stall ? 1'b0 : can_branch;

    register #(160) ID_EX (
        neg_clk,
        {   // 제어 신호 (Stall 시 0으로 변환됨)
            real_reg_write,
            real_mem_to_reg,
            real_can_branch,
            real_mem_read,
            real_mem_write,
            alu_op,      
            alu_src,
            pc_gen_sel,
            sys,
            rd_sel,
            // 데이터 (Stall 시 쓰레기 값이 넘어가도 제어신호가 0이라 안전함)
            IF_ID_PC,
            read_data_1,
            read_data_2,
            imm_out,
            IF_ID_Inst[25],
            IF_ID_Inst[30],
            IF_ID_Inst[`IR_funct3],
            IF_ID_Inst[`IR_rs1],
            IF_ID_Inst[`IR_rs2],
            IF_ID_Inst[`IR_rd]
        }, 
        rst,
        1'b1, // ID/EX는 항상 업데이트 (Bubble을 다음 단계로 밀어내야 하므로)
        {   
            ID_EX_reg_write,
            ID_EX_mem_to_reg,
            ID_EX_can_branch,
            ID_EX_mem_read,
            ID_EX_mem_write,
            ID_EX_alu_op,
            ID_EX_alu_src,
            ID_EX_pc_gen_sel,
            ID_EX_sys,
            ID_EX_rd_sel,
            ID_EX_PC,
            ID_EX_RegR1,
            ID_EX_RegR2,
            ID_EX_Imm,
            ID_Ex_Func25,
            ID_EX_Func,
            ID_EX_Rs1,
            ID_EX_Rs2,
            ID_EX_Rd
        }
    );

    // ----------------------------------------------------------------------
    // 3. EX/MEM Pipeline Register
    // ----------------------------------------------------------------------
    wire [31:0] EX_MEM_BranchAddOut, EX_MEM_ALU_out, EX_MEM_RegR2;
    wire EX_MEM_reg_write, EX_MEM_mem_to_reg, EX_MEM_can_branch, EX_MEM_mem_read, EX_MEM_mem_write, EX_MEM_pc_gen_sel, EX_MEM_sys;
    wire [4:0] EX_MEM_Rd;
    wire [3:0] EX_MEM_branch;
    wire [2:0] EX_MEM_func;
    
    register #(115) EX_MEM (clk,
    {
        ID_EX_reg_write,
        ID_EX_mem_to_reg,
        ID_EX_can_branch,
        ID_EX_mem_read,
        ID_EX_mem_write,
        ID_EX_pc_gen_sel,
        ID_EX_sys,
        pc_gen_out,
        carry_flag,
        zero_flag,
        over_flag,
        sign_flag,
        jump_mux,
        ID_EX_Func[2:0],
        ID_EX_RegR2,
        ID_EX_Rd
    },
    rst,
    1'b1,
    {
         EX_MEM_reg_write,
         EX_MEM_mem_to_reg,
         EX_MEM_can_branch,
         EX_MEM_mem_read,
         EX_MEM_mem_write,
         EX_MEM_pc_gen_sel,
         EX_MEM_sys,
         EX_MEM_BranchAddOut,
         EX_MEM_branch,
         EX_MEM_ALU_out,
         EX_MEM_func,
         EX_MEM_RegR2,
         EX_MEM_Rd
    });
       
    // ----------------------------------------------------------------------
    // 4. MEM/WB Pipeline Register
    // ----------------------------------------------------------------------
    wire [31:0] MEM_WB_Mem_out, MEM_WB_ALU_out;
    wire MEM_WB_reg_write, MEM_WB_mem_to_reg, MEM_WB_sys;
    wire [4:0] MEM_WB_Rd;
    
    register #(72) MEM_WB (neg_clk,
    {
        EX_MEM_reg_write,
        EX_MEM_mem_to_reg,
        EX_MEM_sys,
        data_mem_out,
        EX_MEM_ALU_out,
        EX_MEM_Rd
    },
    rst,
    1'b1,
    {
        MEM_WB_reg_write,
        MEM_WB_mem_to_reg,
        MEM_WB_sys,   
        MEM_WB_Mem_out,
        MEM_WB_ALU_out,
        MEM_WB_Rd
    });

    // ----------------------------------------------------------------------
    // Rest of Logic
    // ----------------------------------------------------------------------
    assign PC_ext = PC;
    assign PC_in_ext = PC_in;
    register#(32) program_counter (neg_clk, final_pc, rst, ~stall, PC); // PC도 Stall일 때 멈춤!
    
    wire [31:0] mem_addr;
    wire final_mem_read;
    wire final_mem_write;
    wire [2:0] final_mem_func;
    
    assign mem_addr = ~clk ? PC : EX_MEM_ALU_out + 6'd48;
    assign final_mem_read = ~clk ? 1'b1 : EX_MEM_mem_read;
    assign final_mem_write = ~clk ? 1'b0 : EX_MEM_mem_write;    
    assign final_mem_func = ~clk ? 3'b010 : EX_MEM_func;
    
    assign inst_out_ext = inst_out;
    wire [31:0] mem_out;
    wire [31:0] mem_inst_out;
    
    DataMem inst_mem (
        .clk(clk),
        .MemRead(final_mem_read),
        .MemWrite(final_mem_write),
        .addr(mem_addr),
        .func3(final_mem_func),
        .data_in(EX_MEM_RegR2),
        .data_out(mem_out),
        .led_reg(led_reg_out),
        .led_reg(led_reg_out),
        .uart_tx_data(uart_tx_data_out),
        .uart_tx_we(uart_tx_we_out),
        .uart_rx_re(uart_rx_re_out),
        .uart_rx_data(uart_rx_data_in),
        .uart_rx_valid(uart_rx_valid_in),
        .uart_tx_busy(uart_tx_busy_in)

    );
    
    // Stall일 때는 명령어 메모리 출력이 의미가 없지만, 굳이 NOP으로 바꿀 필요 없음 (제어신호가 죽었으므로)
    assign mem_inst_out = ~clk & ~stall ? mem_out : 32'h00_00_00_33; 
    assign data_mem_out = ~clk ? mem_out : 1'b1;
    
    wire [31:0] decompressed;
    compressed decompressor (mem_inst_out, decompressed);
    assign inst_out = mem_inst_out[1:0] == 2'b11 ? mem_inst_out : decompressed; 
    
    // 출력 포트 연결
    assign branch_ext = can_branch;
    assign mem_read_ext = mem_read;
    assign mem_to_reg_ext = mem_to_reg;
    assign mem_write_ext = mem_write; 
    assign alu_src_ext = alu_src;
    assign reg_write_ext = reg_write;
    
    assign alu_op_ext = alu_op;
   
    control_unit controlUnit (IF_ID_Inst[6:2], can_branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write,sys, alu_op, rd_sel, pc_gen_sel);
     
    // Hazard Detection Unit
    Hazard_Unit_prediction hazard_detection(IF_ID_Inst[`IR_rs1], IF_ID_Inst[`IR_rs2], ID_EX_Rd, can_branch, stall);

    assign write_data_ext = write_data;
    assign data_read_1_ext = read_data_1;
    assign data_read_2_ext = read_data_2;

    RegFile reg_file (clk, rst, IF_ID_Inst[`IR_rs1], IF_ID_Inst[`IR_rs2], MEM_WB_Rd,
    write_data, MEM_WB_reg_write, read_data_1, read_data_2);
    
    wire flag_comp;
    comparators comp(IF_ID_Inst[`IR_funct3], can_branch, read_data_1, read_data_2, flag_comp);
  
    assign imm_out_ext = imm_out;
    imm_gen immGen (IF_ID_Inst, imm_out);
    
    assign alu_mux_ext = alu_mux_out;
    multiplexer alu_mux (inputB, ID_EX_Imm, ID_EX_alu_src, alu_mux_out);
    
    assign alu_ctrl_out_ext = alu_ctrl_out;
    ALU_op aluOp (ID_EX_alu_op, ID_Ex_Func25, ID_EX_Func[2:0], ID_EX_Func[3], alu_ctrl_out);
    
    assign z_flag_ext = zero_flag;
    assign alu_out_ext = alu_out;
    
    prv32_ALU alu (inputA, alu_mux_out, imm_out[4:0], alu_out, carry_flag, zero_flag, over_flag, sign_flag, alu_ctrl_out);

    assign data_mem_out_ext = data_mem_out;
   
    assign pc_gen_out_ext = pc_gen_out;
    assign pc_gen_in = EX_MEM_pc_gen_sel ? ID_EX_RegR1 : EX_MEM_BranchAddOut;
     
    ripple pc_gen (IF_ID_PC, imm_out, pc_gen_out, dummy_carry);
    
    assign PC_inc_ext = pc_inc_out;
    ripple pc_inc (PC, inst_out[1:0] ?  3'd4 : 3'd2, pc_inc_out, dummy_carry_2);

    multiplexer write_back (MEM_WB_ALU_out, MEM_WB_Mem_out, MEM_WB_mem_to_reg, write_data);
        
    Forward_Unit FU (EX_MEM_reg_write, MEM_WB_reg_write, EX_MEM_Rd, ID_EX_Rs1, ID_EX_Rs2, MEM_WB_Rd, forwardA, forwardB);
    
    assign inputA = (forwardA == 2'b10) ? EX_MEM_ALU_out : (forwardA == 2'b01) ? write_data : ID_EX_RegR1;
    assign inputB = (forwardB == 2'b10) ? EX_MEM_ALU_out : (forwardB == 2'b01) ? write_data : ID_EX_RegR2;

    assign jump_mux = (ID_EX_rd_sel == 2'b00) ? alu_out : (ID_EX_rd_sel == 2'b01) ? pc_gen_out : (ID_EX_rd_sel == 2'b10) ? (ID_EX_PC + 4) : ID_EX_RegR2;
    
    multiplexer pc_mux (pc_inc_out, pc_gen_out, flag_comp, PC_in);
    assign new_PC_in = pc_gen_sel ? PC_in & -2 : PC_in;
    assign final_pc = (MEM_WB_sys & inst_out[20]) ? PC : new_PC_in;

endmodule