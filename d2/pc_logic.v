`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pc_logic.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   Program Counter 관련 로직.
//   - PC 증가 (PC+4)
//   - Branch Target 계산
//   - PC 선택 (순차/분기)
//
// Change History:
//   2024.12.12 - data_path.v에서 분리
//////////////////////////////////////////////////////////////////////////////////

module pc_logic(
    input wire clk,
    input wire rst,
    input wire stall,
    
    // ===== 현재 상태 =====
    input wire [31:0] PC,               // 현재 PC
    input wire [31:0] inst,             // 현재 명령어
    input wire [31:0] IF_ID_PC,         // IF/ID 단계 PC
    input wire [31:0] imm,              // Immediate 값
    
    // ===== 분기 제어 =====
    input wire can_branch,              // 분기 명령어 여부
    input wire [31:0] read_data_1,      // rs1 값
    input wire [31:0] read_data_2,      // rs2 값
    input wire pc_gen_sel,              // JALR 선택
    input wire MEM_WB_sys,              // ECALL/EBREAK
    
    // ===== 출력 =====
    output wire [31:0] PC_out,          // 새 PC 값
    output wire [31:0] pc_inc_out,      // PC + 4
    output wire [31:0] pc_gen_out,      // Branch target
    output wire flag_comp               // 분기 조건 성립 여부
);

    wire dummy_carry, dummy_carry_2;
    wire [31:0] PC_in, new_PC_in, final_pc;
    
    // =========================================================================
    // PC 증가 (PC + 4 또는 PC + 2)
    // =========================================================================
    ripple pc_inc (
        .a(PC),
        .b(inst[1:0] ? 32'd4 : 32'd2),
        .sum(pc_inc_out),
        .carry_out(dummy_carry_2)
    );
    
    // =========================================================================
    // Branch Target 계산 (IF_ID_PC + imm)
    // =========================================================================
    ripple pc_gen (
        .a(IF_ID_PC),
        .b(imm),
        .sum(pc_gen_out),
        .carry_out(dummy_carry)
    );
    
    // =========================================================================
    // 분기 조건 검사 (BEQ: rs1 == rs2)
    // =========================================================================
    assign flag_comp = can_branch && (read_data_1 == read_data_2);
    
    // =========================================================================
    // PC 선택
    // =========================================================================
    multiplexer pc_mux (
        .a(pc_inc_out),
        .b(pc_gen_out),
        .sel(flag_comp),
        .out(PC_in)
    );
    
    // JALR: PC 하위 비트 클리어 (2바이트 정렬)
    assign new_PC_in = pc_gen_sel ? (PC_in & ~32'd1) : PC_in;
    
    // ECALL/EBREAK: PC 유지
    assign final_pc = (MEM_WB_sys & inst[20]) ? PC : new_PC_in;
    
    // =========================================================================
    // Program Counter Register
    // =========================================================================
    register #(32) program_counter (
        .clk(clk),
        .d(final_pc),
        .rst(rst),
        .load(~stall),
        .q(PC_out)
    );

endmodule
