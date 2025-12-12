`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: pipeline_controller.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
// 
// Description: 
//   파이프라인 제어 로직을 담당하는 모듈.
//   - Stall 신호 생성 (Load-Use Hazard)
//   - Flush 신호 생성 (Branch/Jump 시 파이프라인 비우기)
//   - PC 선택 로직 (순차 실행 vs 분기)
//   - MMIO 주소 디코딩
//
// Memory Map:
//   0x00000000 ~ 0x0FFFFFFF : BRAM (Instruction & Data)
//   0x20000000 ~ 0x2FFFFFFF : LED
//   0x30000000 ~ 0x3FFFFFFF : PS2 Keyboard
//   0x40000000 ~ 0x4FFFFFFF : VGA Output
//   0x50000000 ~ 0x5FFFFFFF : Number Input Buffer
//
// Change History:
//   2024.12.11 - Initial creation, separated from data_path.v
//////////////////////////////////////////////////////////////////////////////////

module pipeline_controller(
    input wire clk,
    input wire rst,
    
    // ===== Hazard Detection Inputs =====
    input wire [4:0] IF_ID_rs1,        // IF/ID 단계의 rs1
    input wire [4:0] IF_ID_rs2,        // IF/ID 단계의 rs2
    input wire [4:0] ID_EX_rd,         // ID/EX 단계의 rd (목적지 레지스터)
    input wire ID_EX_mem_read,         // ID/EX 단계의 메모리 읽기 신호 (Load 명령어)
    
    // ===== Branch/Jump Inputs =====
    input wire can_branch,             // Branch 명령어 여부
    input wire branch_taken,           // 분기 조건 성립 여부
    input wire jump,                   // Jump 명령어 여부 (JAL, JALR)
    
    // ===== Control Outputs =====
    output wire stall,                 // 파이프라인 정지 (1 cycle)
    output wire flush,                 // 파이프라인 비우기 (잘못된 명령어 삭제)
    output wire [1:0] pc_sel           // PC 선택: 00=PC+4, 01=Branch, 10=Jump
);

    // =========================================================================
    // 1. Load-Use Hazard Detection (Stall Logic)
    // =========================================================================
    // Load 명령어 직후 해당 레지스터를 사용하는 명령어가 오면 1 cycle stall 필요
    // 예: LW x1, 0(x2)  → x1 로드
    //     ADD x3, x1, x4 → x1 사용 (데이터가 아직 안 옴!)
    
    wire load_use_hazard;
    
    assign load_use_hazard = ID_EX_mem_read && 
                             (ID_EX_rd != 5'b0) &&
                             ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2));
    
    assign stall = load_use_hazard;
    
    // =========================================================================
    // 2. Control Hazard Detection (Flush Logic)
    // =========================================================================
    // Branch가 taken 되었거나 Jump 명령어 실행 시,
    // 이미 fetch된 잘못된 명령어들을 파이프라인에서 제거
    
    assign flush = (can_branch && branch_taken) || jump;
    
    // =========================================================================
    // 3. PC Selection Logic
    // =========================================================================
    // pc_sel encoding:
    //   2'b00 : PC + 4 (순차 실행)
    //   2'b01 : Branch Target Address
    //   2'b10 : Jump Target Address
    
    assign pc_sel = jump ? 2'b10 :
                    (can_branch && branch_taken) ? 2'b01 :
                    2'b00;

endmodule

// =============================================================================
// MMIO 주소 디코딩 모듈 (Address Decoder)
// =============================================================================
// data_path.v에서 호출하여 주소에 따라 적절한 장치 선택

module mmio_decoder(
    input wire [31:0] addr,
    
    output wire is_bram,      // 0x00000000 ~ 0x0FFFFFFF
    output wire is_led,       // 0x20000000 ~ 0x2FFFFFFF
    output wire is_ps2,       // 0x30000000 ~ 0x3FFFFFFF
    output wire is_vga,       // 0x40000000 ~ 0x4FFFFFFF
    output wire is_num_buf,   // 0x50000000 ~ 0x5FFFFFFF
    output wire is_mmio       // BRAM이 아닌 모든 I/O
);

    wire [3:0] addr_hi = addr[31:28];
    
    assign is_bram    = (addr_hi == 4'h0);
    assign is_led     = (addr_hi == 4'h2);
    assign is_ps2     = (addr_hi == 4'h3);
    assign is_vga     = (addr_hi == 4'h4);
    assign is_num_buf = (addr_hi == 4'h5);
    
    assign is_mmio = is_led | is_ps2 | is_vga | is_num_buf;

endmodule
