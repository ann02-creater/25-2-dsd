`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: data_path.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   RISC-V 5단계 파이프라인 데이터패스 (모듈화 버전).
//   파이프라인 레지스터, MMIO, PC 로직을 별도 모듈로 분리.
//
// 하위 모듈:
//   - pipeline_registers.v : IF/ID, ID/EX, EX/MEM, MEM/WB 레지스터
//   - mmio_controller.v    : MMIO Read/Write 처리
//   - pc_logic.v           : PC 계산 및 분기 처리
//
// Memory Map:
//   0x00000000 ~ 0x0FFFFFFF : BRAM
//   0x20000000 : LED Control
//   0x30000000 : PS2 Keyboard Scancode
//   0x50000000 : Number Input Buffer
//
// Change History:
//   2024.12.12 - 모듈화 리팩토링
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module data_path(
    input clk, 
    input rst, 
    
    // 디버그 출력
    output [31:0] inst_out_ext,
    output branch_ext, mem_read_ext, mem_to_reg_ext, mem_write_ext, alu_src_ext, reg_write_ext,
    output [1:0] alu_op_ext,
    output z_flag_ext,
    output [4:0] alu_ctrl_out_ext,
    output [31:0] PC_inc_ext, pc_gen_out_ext, PC_ext, PC_in_ext,
    output [31:0] data_read_1_ext, data_read_2_ext, write_data_ext, imm_out_ext, shift_ext, alu_mux_ext,
    output [31:0] alu_out_ext, data_mem_out_ext,
    output [15:0] led_reg_out,
    output forwarding_active_ext,
    output hazard_stall_ext,
    
    // PS2 Keyboard
    input [7:0] ps2_scancode_in,
    input ps2_key_pressed_in,
    
    // Number Buffer
    input [31:0] num_buffer_in,
    input num_valid_in,
    
    // VGA Result
    output [1:0] vga_result_out
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    wire [31:0] PC, inst_out, inst_mem_out;
    wire [31:0] imm_out, read_data_1, read_data_2, write_data;
    wire [31:0] alu_out, alu_mux_out, data_mem_out, bram_data_out;
    wire [31:0] pc_inc_out, pc_gen_out;
    wire [31:0] inputA, inputB, jump_mux;
    wire [4:0] alu_ctrl_out;
    wire [1:0] alu_op, rd_sel, forwardA, forwardB;
    wire can_branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write, pc_gen_sel, sys;
    wire carry_flag, zero_flag, over_flag, sign_flag, flag_comp;
    wire stall;
    wire is_bram_write;
    
    // Pipeline Register 신호
    wire [31:0] IF_ID_PC, IF_ID_Inst;
    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
    wire ID_EX_reg_write, ID_EX_mem_to_reg, ID_EX_can_branch, ID_EX_mem_read, ID_EX_mem_write;
    wire ID_EX_alu_src, ID_EX_pc_gen_sel, ID_EX_sys, ID_EX_Func25;
    wire [1:0] ID_EX_alu_op, ID_EX_rd_sel;
    wire [3:0] ID_EX_Func;
    wire [4:0] ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd;
    
    wire [31:0] EX_MEM_BranchAddOut, EX_MEM_ALU_out, EX_MEM_RegR2;
    wire EX_MEM_reg_write, EX_MEM_mem_to_reg, EX_MEM_can_branch;
    wire EX_MEM_mem_read, EX_MEM_mem_write, EX_MEM_pc_gen_sel, EX_MEM_sys;
    wire [4:0] EX_MEM_Rd;
    wire [3:0] EX_MEM_branch;
    wire [2:0] EX_MEM_func;
    
    wire [31:0] MEM_WB_Mem_out, MEM_WB_ALU_out;
    wire MEM_WB_reg_write, MEM_WB_mem_to_reg, MEM_WB_sys;
    wire [4:0] MEM_WB_Rd;

    // Stall 시 NOP 삽입
    assign inst_out = stall ? 32'h00000013 : inst_mem_out;

    // =========================================================================
    // Pipeline Registers
    // =========================================================================
    pipeline_registers pipe_regs (
        .clk(clk), .rst(rst), .stall(stall),
        // IF/ID
        .PC_in(PC), .inst_in(inst_out),
        .IF_ID_PC(IF_ID_PC), .IF_ID_Inst(IF_ID_Inst),
        // ID/EX 입력
        .reg_write_in(reg_write), .mem_to_reg_in(mem_to_reg),
        .can_branch_in(can_branch), .mem_read_in(mem_read), .mem_write_in(mem_write),
        .alu_op_in(alu_op), .alu_src_in(alu_src), .pc_gen_sel_in(pc_gen_sel),
        .sys_in(sys), .rd_sel_in(rd_sel),
        .read_data_1_in(read_data_1), .read_data_2_in(read_data_2), .imm_in(imm_out),
        // ID/EX 출력
        .ID_EX_reg_write(ID_EX_reg_write), .ID_EX_mem_to_reg(ID_EX_mem_to_reg),
        .ID_EX_can_branch(ID_EX_can_branch), .ID_EX_mem_read(ID_EX_mem_read),
        .ID_EX_mem_write(ID_EX_mem_write), .ID_EX_alu_op(ID_EX_alu_op),
        .ID_EX_alu_src(ID_EX_alu_src), .ID_EX_pc_gen_sel(ID_EX_pc_gen_sel),
        .ID_EX_sys(ID_EX_sys), .ID_EX_rd_sel(ID_EX_rd_sel),
        .ID_EX_PC(ID_EX_PC), .ID_EX_RegR1(ID_EX_RegR1), .ID_EX_RegR2(ID_EX_RegR2),
        .ID_EX_Imm(ID_EX_Imm), .ID_EX_Func25(ID_EX_Func25), .ID_EX_Func(ID_EX_Func),
        .ID_EX_Rs1(ID_EX_Rs1), .ID_EX_Rs2(ID_EX_Rs2), .ID_EX_Rd(ID_EX_Rd),
        // EX/MEM 입력
        .pc_gen_out_in(pc_gen_out),
        .carry_flag_in(carry_flag), .zero_flag_in(zero_flag),
        .over_flag_in(over_flag), .sign_flag_in(sign_flag),
        .jump_mux_in(jump_mux),
        // EX/MEM 출력
        .EX_MEM_reg_write(EX_MEM_reg_write), .EX_MEM_mem_to_reg(EX_MEM_mem_to_reg),
        .EX_MEM_can_branch(EX_MEM_can_branch), .EX_MEM_mem_read(EX_MEM_mem_read),
        .EX_MEM_mem_write(EX_MEM_mem_write), .EX_MEM_pc_gen_sel(EX_MEM_pc_gen_sel),
        .EX_MEM_sys(EX_MEM_sys), .EX_MEM_BranchAddOut(EX_MEM_BranchAddOut),
        .EX_MEM_branch(EX_MEM_branch), .EX_MEM_ALU_out(EX_MEM_ALU_out),
        .EX_MEM_func(EX_MEM_func), .EX_MEM_RegR2(EX_MEM_RegR2), .EX_MEM_Rd(EX_MEM_Rd),
        // MEM/WB 입력
        .data_mem_out_in(data_mem_out),
        // MEM/WB 출력
        .MEM_WB_reg_write(MEM_WB_reg_write), .MEM_WB_mem_to_reg(MEM_WB_mem_to_reg),
        .MEM_WB_sys(MEM_WB_sys), .MEM_WB_Mem_out(MEM_WB_Mem_out),
        .MEM_WB_ALU_out(MEM_WB_ALU_out), .MEM_WB_Rd(MEM_WB_Rd)
    );

    // =========================================================================
    // BRAM
    // =========================================================================
    blk_mem_gen_0 bram (
        .clka(clk), .ena(1'b1), .wea(4'b0),
        .addra(PC[12:2]), .dina(32'b0), .douta(inst_mem_out),
        .clkb(clk), .enb(1'b1), 
        .web({4{is_bram_write}}),
        .addrb(EX_MEM_ALU_out[12:2]), .dinb(EX_MEM_RegR2), .doutb(bram_data_out)
    );

    // =========================================================================
    // MMIO Controller
    // =========================================================================
    mmio_controller mmio (
        .clk(clk), .rst(rst),
        .mem_write(EX_MEM_mem_write),
        .addr(EX_MEM_ALU_out),
        .write_data(EX_MEM_RegR2),
        .bram_data(bram_data_out),
        .ps2_scancode(ps2_scancode_in),
        .ps2_key_pressed(ps2_key_pressed_in),
        .num_buffer(num_buffer_in),
        .num_valid(num_valid_in),
        .data_out(data_mem_out),
        .led_reg(led_reg_out),
        .vga_result(vga_result_out),
        .is_bram_write(is_bram_write)
    );

    // =========================================================================
    // PC Logic
    // =========================================================================
    pc_logic pc_unit (
        .clk(clk), .rst(rst), .stall(stall),
        .PC(PC), .inst(inst_out),
        .IF_ID_PC(IF_ID_PC), .imm(imm_out),
        .can_branch(can_branch),
        .read_data_1(read_data_1), .read_data_2(read_data_2),
        .pc_gen_sel(pc_gen_sel),
        .MEM_WB_sys(MEM_WB_sys),
        .PC_out(PC),
        .pc_inc_out(pc_inc_out),
        .pc_gen_out(pc_gen_out),
        .flag_comp(flag_comp)
    );

    // =========================================================================
    // Control Unit & Hazard Detection
    // =========================================================================
    control_unit controlUnit (
        IF_ID_Inst[6:2], 
        can_branch, mem_read, mem_to_reg, mem_write, 
        alu_src, reg_write, sys, alu_op, rd_sel, pc_gen_sel
    );
     
    Hazard_Unit_prediction hazard_detection (
        IF_ID_Inst[`IR_rs1], IF_ID_Inst[`IR_rs2], 
        ID_EX_Rd, can_branch, stall
    );

    // =========================================================================
    // Register File
    // =========================================================================
    RegFile reg_file (
        clk, rst, 
        IF_ID_Inst[`IR_rs1], IF_ID_Inst[`IR_rs2], MEM_WB_Rd,
        write_data, MEM_WB_reg_write, 
        read_data_1, read_data_2
    );

    // =========================================================================
    // Immediate Generator
    // =========================================================================
    imm_gen immGen (IF_ID_Inst, imm_out);

    // =========================================================================
    // ALU & Forwarding
    // =========================================================================
    multiplexer alu_mux (inputB, ID_EX_Imm, ID_EX_alu_src, alu_mux_out);
    
    ALU_op aluOp (ID_EX_alu_op, ID_EX_Func25, ID_EX_Func[2:0], ID_EX_Func[3], alu_ctrl_out);
    
    prv32_ALU alu (inputA, alu_mux_out, imm_out[4:0], alu_out, carry_flag, zero_flag, over_flag, sign_flag, alu_ctrl_out);
    
    Forward_Unit FU (EX_MEM_reg_write, MEM_WB_reg_write, EX_MEM_Rd, ID_EX_Rs1, ID_EX_Rs2, MEM_WB_Rd, forwardA, forwardB);
    
    assign inputA = (forwardA == 2'b10) ? EX_MEM_ALU_out : (forwardA == 2'b01) ? write_data : ID_EX_RegR1;
    assign inputB = (forwardB == 2'b10) ? EX_MEM_ALU_out : (forwardB == 2'b01) ? write_data : ID_EX_RegR2;

    // =========================================================================
    // Write Back
    // =========================================================================
    multiplexer write_back (MEM_WB_ALU_out, MEM_WB_Mem_out, MEM_WB_mem_to_reg, write_data);
    
    assign jump_mux = (ID_EX_rd_sel == 2'b00) ? alu_out : 
                      (ID_EX_rd_sel == 2'b01) ? pc_gen_out : 
                      (ID_EX_rd_sel == 2'b10) ? (ID_EX_PC + 4) : ID_EX_RegR2;

    // =========================================================================
    // Debug Outputs
    // =========================================================================
    assign inst_out_ext = inst_out;
    assign branch_ext = can_branch;
    assign mem_read_ext = mem_read;
    assign mem_to_reg_ext = mem_to_reg;
    assign mem_write_ext = mem_write; 
    assign alu_src_ext = alu_src;
    assign reg_write_ext = reg_write;
    assign alu_op_ext = alu_op;
    assign z_flag_ext = zero_flag;
    assign alu_ctrl_out_ext = alu_ctrl_out;
    assign PC_inc_ext = pc_inc_out;
    assign pc_gen_out_ext = pc_gen_out;
    assign PC_ext = PC;
    assign PC_in_ext = PC;
    assign data_read_1_ext = read_data_1;
    assign data_read_2_ext = read_data_2;
    assign write_data_ext = write_data;
    assign imm_out_ext = imm_out;
    assign shift_ext = 32'b0;
    assign alu_mux_ext = alu_mux_out;
    assign alu_out_ext = alu_out;
    assign data_mem_out_ext = data_mem_out;
    assign forwarding_active_ext = (forwardA != 2'b00) || (forwardB != 2'b00);
    assign hazard_stall_ext = stall;

endmodule