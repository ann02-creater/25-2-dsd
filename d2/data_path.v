`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: data_path.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   RISC-V 5단계 파이프라인 데이터패스.
//   - IF: Instruction Fetch
//   - ID: Instruction Decode + Register Read
//   - EX: Execute (ALU)
//   - MEM: Memory Access + MMIO
//   - WB: Write Back
//
// Memory Map:
//   0x00000000 ~ 0x0FFFFFFF : BRAM
//   0x10000000 : UART Data (기존 호환용)
//   0x10000004 : UART Status (기존 호환용)
//   0x20000000 : LED Control
//   0x30000000 : PS2 Keyboard ASCII (NEW)
//   0x30000004 : PS2 Key Valid (NEW)
//   0x40000000 : VGA Result (NEW)
//   0x50000000 : Number Input Buffer (NEW)
//   0x50000004 : Number Valid Flag (NEW)
//
// Change History:
//   2024.12.11 - PS2/VGA MMIO 확장, 헤더 정리
//////////////////////////////////////////////////////////////////////////////////
`include "defines.v"

module data_path(
    input clk, input rst, 
    // 디버그 출력
    output [31:0]inst_out_ext, output branch_ext, mem_read_ext, mem_to_reg_ext, mem_write_ext, alu_src_ext, reg_write_ext,
    output [1:0]alu_op_ext, output z_flag_ext, output [4:0]alu_ctrl_out_ext, output [31:0]PC_inc_ext, output [31:0]pc_gen_out_ext, output [31:0]PC_ext, output [31:0]PC_in_ext,
    output [31:0]data_read_1_ext, output [31:0]data_read_2_ext, output [31:0]write_data_ext, output [31:0]imm_out_ext, output [31:0]shift_ext, output [31:0]alu_mux_ext,
    output [31:0]alu_out_ext, output [31:0]data_mem_out_ext, output reg [15:0] led_reg_out,
    // UART (기존 호환용)
    output reg [7:0]  uart_tx_data_out,
    output reg        uart_tx_we_out,
    output            uart_rx_re_out,
    input  [7:0]      uart_rx_data_in,
    input             uart_rx_valid_in,
    input             uart_tx_busy_in,
    output            forwarding_active_ext,
    output            hazard_stall_ext,
    // PS2 Keyboard
    input  [7:0]      ps2_scancode_in,
    input             ps2_key_pressed_in,
    // Number Buffer
    input  [31:0]     num_buffer_in,
    input             num_valid_in,
    // VGA Result
    output reg [1:0]  vga_result_out
);

    // Internal signals
    wire [31:0] jump_mux;
    reg [31:0] data_mem_out;
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
    wire [31:0] pc_gen_out;
    wire dummy_carry;
    wire [31:0] pc_gen_in;
    wire [31:0] pc_inc_out;
    wire dummy_carry_2;
    wire [1:0] forwardA, forwardB;
    wire [31:0] inputA, inputB;
    wire stall;

    // =========================================================================
    // 1. IF/ID Pipeline Register
    // =========================================================================
    wire [31:0] IF_ID_PC, IF_ID_Inst;
   
    register #(64) IF_ID (
        clk,
        {PC, inst_out},
        rst,
        ~stall,  // Stall시 Freeze
        {IF_ID_PC, IF_ID_Inst}
    );

    // =========================================================================
    // 2. ID/EX Pipeline Register
    // =========================================================================
    wire [31:0] ID_EX_PC, ID_EX_RegR1, ID_EX_RegR2, ID_EX_Imm;
    wire ID_EX_can_branch, ID_EX_mem_read, ID_EX_mem_to_reg, ID_EX_mem_write, ID_EX_alu_src, ID_EX_reg_write, ID_EX_pc_gen_sel, ID_EX_sys;
    wire [1:0] ID_EX_alu_op, ID_EX_rd_sel; 
    wire [3:0] ID_EX_Func;
    wire [4:0] ID_EX_Rs1, ID_EX_Rs2, ID_EX_Rd;
    wire ID_Ex_Func25;

    // Stall시 control signal을 0으로 (Bubble)
    wire real_reg_write  = stall ? 1'b0 : reg_write;
    wire real_mem_to_reg = stall ? 1'b0 : mem_to_reg;
    wire real_mem_read   = stall ? 1'b0 : mem_read;
    wire real_mem_write  = stall ? 1'b0 : mem_write;
    wire real_can_branch = stall ? 1'b0 : can_branch;

    register #(160) ID_EX (
        clk,
        {
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
        1'b1,
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

    // =========================================================================
    // 3. EX/MEM Pipeline Register
    // =========================================================================
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
       
    // =========================================================================
    // 4. MEM/WB Pipeline Register
    // =========================================================================
    wire [31:0] MEM_WB_Mem_out, MEM_WB_ALU_out;
    wire MEM_WB_reg_write, MEM_WB_mem_to_reg, MEM_WB_sys;
    wire [4:0] MEM_WB_Rd;
    
    register #(72) MEM_WB (clk,
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

    // =========================================================================
    // BRAM & MMIO
    // =========================================================================
    assign PC_ext = PC;
    assign PC_in_ext = PC_in;
    register#(32) program_counter (clk, final_pc, rst, ~stall, PC);

    assign inst_out_ext = inst_out;
    wire [31:0] inst_mem_out;
    wire [31:0] bram_data_out;

    // MMIO 주소 디코딩 (상위 4비트로 구분)
    wire [3:0] addr_hi = EX_MEM_ALU_out[31:28];
    wire is_bram    = (addr_hi == 4'h0);
    wire is_uart    = (addr_hi == 4'h1);
    wire is_led     = (addr_hi == 4'h2);
    wire is_ps2     = (addr_hi == 4'h3);
    wire is_vga     = (addr_hi == 4'h4);
    wire is_num_buf = (addr_hi == 4'h5);
    wire is_mmio    = ~is_bram;

    // BRAM
    blk_mem_gen_0 bram (
        .clka(clk), .ena(1'b1), .wea(4'b0),
        .addra(PC[12:2]), .dina(32'b0), .douta(inst_mem_out),
        .clkb(clk), .enb(1'b1), 
        .web({4{EX_MEM_mem_write && is_bram}}),  // MMIO 주소면 BRAM 쓰기 안함
        .addrb(EX_MEM_ALU_out[12:2]), .dinb(EX_MEM_RegR2), .doutb(bram_data_out)
    );

    // =========================================================================
    // MMIO Read (lw 명령어)
    // =========================================================================
    always @(*) begin
        case (addr_hi)
            4'h1: begin
                // UART
                if (EX_MEM_ALU_out[3:0] == 4'h0)
                    data_mem_out = {24'b0, uart_rx_data_in};
                else
                    data_mem_out = {30'b0, uart_tx_busy_in, uart_rx_valid_in};
            end
            4'h3: begin
                // PS2 Keyboard
                if (EX_MEM_ALU_out[3:0] == 4'h0)
                    data_mem_out = {24'b0, ps2_scancode_in};
                else
                    data_mem_out = {31'b0, ps2_key_pressed_in};
            end
            4'h5: begin
                // Number Buffer
                if (EX_MEM_ALU_out[3:0] == 4'h0)
                    data_mem_out = num_buffer_in;
                else
                    data_mem_out = {31'b0, num_valid_in};
            end
            default: data_mem_out = bram_data_out;
        endcase
    end

    // =========================================================================
    // MMIO Write (sw 명령어)
    // =========================================================================
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            led_reg_out <= 16'h0;
            uart_tx_data_out <= 8'h0;
            uart_tx_we_out <= 1'b0;
            vga_result_out <= 2'b00;
        end
        else if (EX_MEM_mem_write) begin
            case (addr_hi)
                4'h1: begin
                    // UART TX
                    uart_tx_data_out <= EX_MEM_RegR2[7:0];
                    uart_tx_we_out <= 1'b1;
                end
                4'h2: begin
                    // LED
                    led_reg_out <= EX_MEM_RegR2[15:0];
                    uart_tx_we_out <= 1'b0;
                end
                4'h4: begin
                    // VGA Result
                    vga_result_out <= EX_MEM_RegR2[1:0];
                    uart_tx_we_out <= 1'b0;
                end
                default: begin
                    uart_tx_we_out <= 1'b0;
                end
            endcase
        end
        else begin
            uart_tx_we_out <= 1'b0;
        end
    end

    // =========================================================================
    // Control & Hazard
    // =========================================================================
    assign inst_out = stall ? 32'h00000013 : inst_mem_out;  // NOP on stall
    
    assign branch_ext = can_branch;
    assign mem_read_ext = mem_read;
    assign mem_to_reg_ext = mem_to_reg;
    assign mem_write_ext = mem_write; 
    assign alu_src_ext = alu_src;
    assign reg_write_ext = reg_write;
    assign alu_op_ext = alu_op;
   
    control_unit controlUnit (IF_ID_Inst[6:2], can_branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write, sys, alu_op, rd_sel, pc_gen_sel);
     
    Hazard_Unit_prediction hazard_detection(IF_ID_Inst[`IR_rs1], IF_ID_Inst[`IR_rs2], ID_EX_Rd, can_branch, stall);

    // =========================================================================
    // Register File & ALU
    // =========================================================================
    assign write_data_ext = write_data;
    assign data_read_1_ext = read_data_1;
    assign data_read_2_ext = read_data_2;

    RegFile reg_file (clk, rst, IF_ID_Inst[`IR_rs1], IF_ID_Inst[`IR_rs2], MEM_WB_Rd,
        write_data, MEM_WB_reg_write, read_data_1, read_data_2);
    
    wire flag_comp;
    assign flag_comp = can_branch && (read_data_1 == read_data_2);  

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
   
    // =========================================================================
    // PC Logic
    // =========================================================================
    assign pc_gen_out_ext = pc_gen_out;
    assign pc_gen_in = EX_MEM_pc_gen_sel ? ID_EX_RegR1 : EX_MEM_BranchAddOut;
     
    ripple pc_gen (IF_ID_PC, imm_out, pc_gen_out, dummy_carry);
    ripple pc_inc (PC, inst_out[1:0] ? 3'd4 : 3'd2, pc_inc_out, dummy_carry_2);

    multiplexer write_back (MEM_WB_ALU_out, MEM_WB_Mem_out, MEM_WB_mem_to_reg, write_data);
        
    Forward_Unit FU (EX_MEM_reg_write, MEM_WB_reg_write, EX_MEM_Rd, ID_EX_Rs1, ID_EX_Rs2, MEM_WB_Rd, forwardA, forwardB);
    
    assign inputA = (forwardA == 2'b10) ? EX_MEM_ALU_out : (forwardA == 2'b01) ? write_data : ID_EX_RegR1;
    assign inputB = (forwardB == 2'b10) ? EX_MEM_ALU_out : (forwardB == 2'b01) ? write_data : ID_EX_RegR2;

    assign jump_mux = (ID_EX_rd_sel == 2'b00) ? alu_out : (ID_EX_rd_sel == 2'b01) ? pc_gen_out : (ID_EX_rd_sel == 2'b10) ? (ID_EX_PC + 4) : ID_EX_RegR2;
    
    multiplexer pc_mux (pc_inc_out, pc_gen_out, flag_comp, PC_in);
    assign new_PC_in = pc_gen_sel ? PC_in & -2 : PC_in;
    assign final_pc = (MEM_WB_sys & inst_out[20]) ? PC : new_PC_in;
    
    // Debug outputs
    assign forwarding_active_ext = (forwardA != 2'b00) || (forwardB != 2'b00);
    assign hazard_stall_ext = stall;

endmodule