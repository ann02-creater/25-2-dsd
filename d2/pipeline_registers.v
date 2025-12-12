`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pipeline_registers.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   파이프라인 레지스터 모듈. 4개의 파이프라인 스테이지 간 데이터 전달.
//   - IF/ID: Instruction Fetch → Instruction Decode
//   - ID/EX: Instruction Decode → Execute
//   - EX/MEM: Execute → Memory Access
//   - MEM/WB: Memory Access → Write Back
//
// Change History:
//   2024.12.12 - data_path.v에서 분리
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module pipeline_registers(
    input wire clk,
    input wire rst,
    input wire stall,
    
    // ===== IF/ID 입력 =====
    input wire [31:0] PC_in,
    input wire [31:0] inst_in,
    
    // ===== IF/ID 출력 =====
    output wire [31:0] IF_ID_PC,
    output wire [31:0] IF_ID_Inst,
    
    // ===== ID/EX 입력 =====
    input wire reg_write_in,
    input wire mem_to_reg_in,
    input wire can_branch_in,
    input wire mem_read_in,
    input wire mem_write_in,
    input wire [1:0] alu_op_in,
    input wire alu_src_in,
    input wire pc_gen_sel_in,
    input wire sys_in,
    input wire [1:0] rd_sel_in,
    input wire [31:0] read_data_1_in,
    input wire [31:0] read_data_2_in,
    input wire [31:0] imm_in,
    
    // ===== ID/EX 출력 =====
    output wire ID_EX_reg_write,
    output wire ID_EX_mem_to_reg,
    output wire ID_EX_can_branch,
    output wire ID_EX_mem_read,
    output wire ID_EX_mem_write,
    output wire [1:0] ID_EX_alu_op,
    output wire ID_EX_alu_src,
    output wire ID_EX_pc_gen_sel,
    output wire ID_EX_sys,
    output wire [1:0] ID_EX_rd_sel,
    output wire [31:0] ID_EX_PC,
    output wire [31:0] ID_EX_RegR1,
    output wire [31:0] ID_EX_RegR2,
    output wire [31:0] ID_EX_Imm,
    output wire ID_EX_Func25,
    output wire [3:0] ID_EX_Func,
    output wire [4:0] ID_EX_Rs1,
    output wire [4:0] ID_EX_Rs2,
    output wire [4:0] ID_EX_Rd,
    
    // ===== EX/MEM 입력 =====
    input wire [31:0] pc_gen_out_in,
    input wire carry_flag_in,
    input wire zero_flag_in,
    input wire over_flag_in,
    input wire sign_flag_in,
    input wire [31:0] jump_mux_in,
    
    // ===== EX/MEM 출력 =====
    output wire EX_MEM_reg_write,
    output wire EX_MEM_mem_to_reg,
    output wire EX_MEM_can_branch,
    output wire EX_MEM_mem_read,
    output wire EX_MEM_mem_write,
    output wire EX_MEM_pc_gen_sel,
    output wire EX_MEM_sys,
    output wire [31:0] EX_MEM_BranchAddOut,
    output wire [3:0] EX_MEM_branch,
    output wire [31:0] EX_MEM_ALU_out,
    output wire [2:0] EX_MEM_func,
    output wire [31:0] EX_MEM_RegR2,
    output wire [4:0] EX_MEM_Rd,
    
    // ===== MEM/WB 입력 =====
    input wire [31:0] data_mem_out_in,
    
    // ===== MEM/WB 출력 =====
    output wire MEM_WB_reg_write,
    output wire MEM_WB_mem_to_reg,
    output wire MEM_WB_sys,
    output wire [31:0] MEM_WB_Mem_out,
    output wire [31:0] MEM_WB_ALU_out,
    output wire [4:0] MEM_WB_Rd
);

    // =========================================================================
    // Stall 시 Bubble 삽입 (control signal을 0으로)
    // =========================================================================
    wire real_reg_write  = stall ? 1'b0 : reg_write_in;
    wire real_mem_to_reg = stall ? 1'b0 : mem_to_reg_in;
    wire real_mem_read   = stall ? 1'b0 : mem_read_in;
    wire real_mem_write  = stall ? 1'b0 : mem_write_in;
    wire real_can_branch = stall ? 1'b0 : can_branch_in;

    // =========================================================================
    // 1. IF/ID Pipeline Register
    // =========================================================================
    register #(64) IF_ID (
        .clk(clk),
        .d({PC_in, inst_in}),
        .rst(rst),
        .load(~stall),
        .q({IF_ID_PC, IF_ID_Inst})
    );

    // =========================================================================
    // 2. ID/EX Pipeline Register
    // =========================================================================
    register #(160) ID_EX (
        .clk(clk),
        .d({
            real_reg_write,
            real_mem_to_reg,
            real_can_branch,
            real_mem_read,
            real_mem_write,
            alu_op_in,      
            alu_src_in,
            pc_gen_sel_in,
            sys_in,
            rd_sel_in,
            IF_ID_PC,
            read_data_1_in,
            read_data_2_in,
            imm_in,
            IF_ID_Inst[25],
            IF_ID_Inst[30],
            IF_ID_Inst[`IR_funct3],
            IF_ID_Inst[`IR_rs1],
            IF_ID_Inst[`IR_rs2],
            IF_ID_Inst[`IR_rd]
        }), 
        .rst(rst),
        .load(1'b1),
        .q({
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
            ID_EX_Func25,
            ID_EX_Func,
            ID_EX_Rs1,
            ID_EX_Rs2,
            ID_EX_Rd
        })
    );

    // =========================================================================
    // 3. EX/MEM Pipeline Register
    // =========================================================================
    register #(115) EX_MEM (
        .clk(clk),
        .d({
            ID_EX_reg_write,
            ID_EX_mem_to_reg,
            ID_EX_can_branch,
            ID_EX_mem_read,
            ID_EX_mem_write,
            ID_EX_pc_gen_sel,
            ID_EX_sys,
            pc_gen_out_in,
            carry_flag_in,
            zero_flag_in,
            over_flag_in,
            sign_flag_in,
            jump_mux_in,
            ID_EX_Func[2:0],
            ID_EX_RegR2,
            ID_EX_Rd
        }),
        .rst(rst),
        .load(1'b1),
        .q({
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
        })
    );
       
    // =========================================================================
    // 4. MEM/WB Pipeline Register
    // =========================================================================
    register #(72) MEM_WB (
        .clk(clk),
        .d({
            EX_MEM_reg_write,
            EX_MEM_mem_to_reg,
            EX_MEM_sys,
            data_mem_out_in,
            EX_MEM_ALU_out,
            EX_MEM_Rd
        }),
        .rst(rst),
        .load(1'b1),
        .q({
            MEM_WB_reg_write,
            MEM_WB_mem_to_reg,
            MEM_WB_sys,
            MEM_WB_Mem_out,
            MEM_WB_ALU_out,
            MEM_WB_Rd
        })
    );

endmodule
