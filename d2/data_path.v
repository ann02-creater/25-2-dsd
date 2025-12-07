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
    output [31:0]alu_out_ext, output [31:0]data_mem_out_ext, output reg [15:0] led_reg_out,

    output reg [7:0]  uart_tx_data_out,
    output reg       uart_tx_we_out,
    output reg       uart_rx_re_out,
    input  [7:0]  uart_rx_data_in,
    input         uart_rx_valid_in,
    input         uart_tx_busy_in
);

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
    
    // ?åå?ù¥?îÑ?ùº?ù∏ ?†àÏß??ä§?Ñ∞ Ï∂úÎ†• ???ù¥?ñ¥ ?Ñ†?ñ∏
    wire [31:0] IF_ID_PC, IF_ID_Inst;
   
    // IF-ID ?†àÏß??ä§?Ñ∞: Stall ?ã†?ò∏(Hazard Unit?óê?Ñú ?ò¥)Í∞? 0?ùº ?ïåÎß? ?óÖ?ç∞?ù¥?ä∏
    // Stall?ù¥ 1?ù¥Î©? Enable?ù¥ 0?ù¥ ?êò?ñ¥ ?ù¥?†Ñ Í∞íÏùÑ ?ú†Ïß??ï® (Freeze)
    register #(64) IF_ID (
        clk,
        {PC, inst_out},        // ?ûÖ?†•
        rst,
        ~stall,                // Enable (Stall?ùº ?ïå Î©àÏ∂§)
        {IF_ID_PC, IF_ID_Inst} // Ï∂úÎ†•
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

    // ?òÖ Stall Î∞úÏÉù ?ãú ID/EXÎ°? ?Ñò?ñ¥Í∞??äî ?†ú?ñ¥ ?ã†?ò∏Î•? 0?úºÎ°? ÎßåÎì¶ (Í±∞Ìíà Ï£ºÏûÖ) ?òÖ
    wire real_reg_write  = stall ? 1'b0 : reg_write;
    wire real_mem_to_reg = stall ? 1'b0 : mem_to_reg;
    wire real_mem_read   = stall ? 1'b0 : mem_read;
    wire real_mem_write  = stall ? 1'b0 : mem_write;
    wire real_can_branch = stall ? 1'b0 : can_branch;

    register #(160) ID_EX (
        clk,
        {   // ?†ú?ñ¥ ?ã†?ò∏ (Stall ?ãú 0?úºÎ°? Î≥??ôò?ê®)
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
            // ?ç∞?ù¥?Ñ∞ (Stall ?ãú ?ì∞?†àÍ∏? Í∞íÏù¥ ?Ñò?ñ¥Í∞??èÑ ?†ú?ñ¥?ã†?ò∏Í∞? 0?ù¥?ùº ?ïà?†Ñ?ï®)
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
        1'b1, // ID/EX?äî ?ï≠?ÉÅ ?óÖ?ç∞?ù¥?ä∏ (Bubble?ùÑ ?ã§?ùå ?ã®Í≥ÑÎ°ú Î∞??ñ¥?Ç¥?ïº ?ïòÎØ?Î°?)
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

    // ----------------------------------------------------------------------
    // Rest of Logic
    // ----------------------------------------------------------------------
    assign PC_ext = PC;
    assign PC_in_ext = PC_in;
    register#(32) program_counter (clk, final_pc, rst, ~stall, PC);

    assign inst_out_ext = inst_out;
    wire [31:0] inst_mem_out;
    wire [31:0] bram_data_out;

    // Vivado IP: True Dual Port BRAM (8KB, 2048x32)
    // Port A: Instruction (read-only), Port B: Data (read/write)
    blk_mem_gen_0 bram (
        .clka(clk), .ena(1'b1), .wea(4'b0),
        .addra(PC[12:2]), .dina(32'b0), .douta(inst_mem_out),
        .clkb(clk), .enb(1'b1), .web({4{EX_MEM_mem_write}}),
        .addrb(EX_MEM_ALU_out[12:2]), .dinb(EX_MEM_RegR2), .doutb(bram_data_out)
    );

    // UART RX read enable signal generation
    reg uart_rx_re_out_reg;
    always@(*) begin uart_rx_re_out = uart_rx_re_out_reg;
    end
    always @(*) begin
        uart_rx_re_out_reg = 1'b0;
        // When reading UART data address, acknowledge the read
        if (EX_MEM_mem_read && (EX_MEM_ALU_out == 32'h1000_0000)) begin
            uart_rx_re_out_reg = 1'b1;
        end
    end

    // Memory-mapped I/O and BRAM data mux
    reg [31:0] data_mem_out;
    always @(*) begin
        if (EX_MEM_ALU_out == 32'h1000_0000)
            data_mem_out = {24'b0, uart_rx_data_in};
        else if (EX_MEM_ALU_out == 32'h1000_0004)
            data_mem_out = {30'b0, uart_tx_busy_in, uart_rx_valid_in};
        else
            data_mem_out = bram_data_out;
    end

    // LED and UART control
    always @(posedge clk) begin
        if (EX_MEM_mem_write) begin
            if (EX_MEM_ALU_out == 32'h2000_0000)
                led_reg_out <= EX_MEM_RegR2[15:0];
            else if (EX_MEM_ALU_out == 32'h1000_0000) begin
                uart_tx_data_out <= EX_MEM_RegR2[7:0];
                uart_tx_we_out <= 1'b1;
            end else
                uart_tx_we_out <= 1'b0;
        end else
            uart_tx_we_out <= 1'b0;
    end

    // Instruction output (compressed instruction support removed)
    // NOP insertion during stall
    assign inst_out = stall ? 32'h00_00_00_33 : inst_mem_out; 
    
    // Ï∂úÎ†• ?è¨?ä∏ ?ó∞Í≤?
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
    assign shift_ext = 32'b0; 
    

endmodule