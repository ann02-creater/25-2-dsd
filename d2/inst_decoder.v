`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: inst_decoder
// Description: RISC-V instruction decoder for 7-segment display
//              Converts 32-bit instruction to 8-digit mnemonic display
//              Format: [Mnemonic (3-4 chars)] [Space] [Operands (3-4 chars)]
//////////////////////////////////////////////////////////////////////////////////

module inst_decoder(
    input [31:0] instruction,
    output reg [6:0] seg0, seg1, seg2, seg3, seg4, seg5, seg6, seg7
);

    // Instruction fields
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [6:0] funct7 = instruction[31:25];
    
    // 7-segment character encoding (active low, segments: gfedcba)
    function [6:0] char_to_seg;
        input [7:0] c;
        begin
            case (c)
                "0": char_to_seg = 7'b1000000;
                "1": char_to_seg = 7'b1111001;
                "2": char_to_seg = 7'b0100100;
                "3": char_to_seg = 7'b0110000;
                "4": char_to_seg = 7'b0011001;
                "5": char_to_seg = 7'b0010010;
                "6": char_to_seg = 7'b0000010;
                "7": char_to_seg = 7'b1111000;
                "8": char_to_seg = 7'b0000000;
                "9": char_to_seg = 7'b0010000;
                "A": char_to_seg = 7'b0001000;
                "B": char_to_seg = 7'b0000011; // lowercase b
                "C": char_to_seg = 7'b1000110;
                "D": char_to_seg = 7'b0100001; // lowercase d
                "E": char_to_seg = 7'b0000110;
                "F": char_to_seg = 7'b0001110;
                "G": char_to_seg = 7'b0010000; // like 9
                "H": char_to_seg = 7'b0001001;
                "I": char_to_seg = 7'b1111001; // like 1
                "J": char_to_seg = 7'b1100001;
                "L": char_to_seg = 7'b1000111;
                "O": char_to_seg = 7'b1000000; // like 0
                "P": char_to_seg = 7'b0001100;
                "Q": char_to_seg = 7'b0011000; // lowercase q
                "R": char_to_seg = 7'b0101111; // lowercase r
                "S": char_to_seg = 7'b0010010; // like 5
                "T": char_to_seg = 7'b0000111; // lowercase t
                "U": char_to_seg = 7'b1000001;
                "Y": char_to_seg = 7'b0010001;
                " ": char_to_seg = 7'b1111111; // blank
                default: char_to_seg = 7'b1111111;
            endcase
        end
    endfunction
    
    // Convert hex digit to character
    function [7:0] hex_to_char;
        input [3:0] hex;
        begin
            if (hex <= 4'h9)
                hex_to_char = "0" + hex;
            else
                hex_to_char = "A" + (hex - 4'hA);
        end
    endfunction
    
    always @(*) begin
        // Default: show hex instruction
        seg7 = char_to_seg(hex_to_char(instruction[31:28]));
        seg6 = char_to_seg(hex_to_char(instruction[27:24]));
        seg5 = char_to_seg(hex_to_char(instruction[23:20]));
        seg4 = char_to_seg(hex_to_char(instruction[19:16]));
        seg3 = char_to_seg(hex_to_char(instruction[15:12]));
        seg2 = char_to_seg(hex_to_char(instruction[11:8]));
        seg1 = char_to_seg(hex_to_char(instruction[7:4]));
        seg0 = char_to_seg(hex_to_char(instruction[3:0]));
        
        case (opcode[6:2])
            // R-type: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
            5'b01100: begin
                case ({funct7[5], funct3})
                    4'b0_000: begin // ADD
                        seg7 = char_to_seg("A");
                        seg6 = char_to_seg("D");
                        seg5 = char_to_seg("D");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b1_000: begin // SUB
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("U");
                        seg5 = char_to_seg("B");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_111: begin // AND
                        seg7 = char_to_seg("A");
                        seg6 = char_to_seg("N");
                        seg5 = char_to_seg("D");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_110: begin // OR
                        seg7 = char_to_seg("O");
                        seg6 = char_to_seg("R");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_100: begin // XOR
                        seg7 = char_to_seg("X");
                        seg6 = char_to_seg("O");
                        seg5 = char_to_seg("R");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_001: begin // SLL
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("L");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_101: begin // SRL
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("R");
                        seg5 = char_to_seg("L");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b1_101: begin // SRA
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("R");
                        seg5 = char_to_seg("A");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_010: begin // SLT
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("T");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    4'b0_011: begin // SLTU
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("T");
                        seg4 = char_to_seg("U");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                endcase
            end
            
            // I-type Arithmetic: ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI
            5'b00100: begin
                case (funct3)
                    3'b000: begin // ADDI
                        seg7 = char_to_seg("A");
                        seg6 = char_to_seg("D");
                        seg5 = char_to_seg("D");
                        seg4 = char_to_seg("I");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20])); // imm[11:8]
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b111: begin // ANDI
                        seg7 = char_to_seg("A");
                        seg6 = char_to_seg("N");
                        seg5 = char_to_seg("D");
                        seg4 = char_to_seg("I");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b110: begin // ORI
                        seg7 = char_to_seg("O");
                        seg6 = char_to_seg("R");
                        seg5 = char_to_seg("I");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b100: begin // XORI
                        seg7 = char_to_seg("X");
                        seg6 = char_to_seg("O");
                        seg5 = char_to_seg("R");
                        seg4 = char_to_seg("I");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b010: begin // SLTI
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("T");
                        seg4 = char_to_seg("I");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b011: begin // SLTIU
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("T");
                        seg4 = char_to_seg("U");
                        seg3 = char_to_seg("I");
                        seg2 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                endcase
            end
            
            // Load: LW, LH, LB, LHU, LBU
            5'b00000: begin
                case (funct3)
                    3'b010: begin // LW
                        seg7 = char_to_seg("L");
                        seg6 = char_to_seg("W");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20])); // offset
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b001: begin // LH
                        seg7 = char_to_seg("L");
                        seg6 = char_to_seg("H");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b000: begin // LB
                        seg7 = char_to_seg("L");
                        seg6 = char_to_seg("B");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b101: begin // LHU
                        seg7 = char_to_seg("L");
                        seg6 = char_to_seg("H");
                        seg5 = char_to_seg("U");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b100: begin // LBU
                        seg7 = char_to_seg("L");
                        seg6 = char_to_seg("B");
                        seg5 = char_to_seg("U");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[23:20]));
                        seg1 = char_to_seg(hex_to_char(rd[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                endcase
            end
            
            // Store: SW, SH, SB
            5'b01000: begin
                case (funct3)
                    3'b010: begin // SW
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("W");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[27:24])); // offset[11:8]
                        seg1 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b001: begin // SH
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("H");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[27:24]));
                        seg1 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b000: begin // SB
                        seg7 = char_to_seg("S");
                        seg6 = char_to_seg("B");
                        seg5 = char_to_seg(" ");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(instruction[27:24]));
                        seg1 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg0 = char_to_seg(" ");
                    end
                endcase
            end
            
            // Branch: BEQ, BNE, BLT, BGE, BLTU, BGEU
            5'b11000: begin
                case (funct3)
                    3'b000: begin // BEQ
                        seg7 = char_to_seg("B");
                        seg6 = char_to_seg("E");
                        seg5 = char_to_seg("Q");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(instruction[11:8])); // imm
                        seg0 = char_to_seg(" ");
                    end
                    3'b001: begin // BNE
                        seg7 = char_to_seg("B");
                        seg6 = char_to_seg("N");
                        seg5 = char_to_seg("E");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(instruction[11:8]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b100: begin // BLT
                        seg7 = char_to_seg("B");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("T");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(instruction[11:8]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b101: begin // BGE
                        seg7 = char_to_seg("B");
                        seg6 = char_to_seg("G");
                        seg5 = char_to_seg("E");
                        seg4 = char_to_seg(" ");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(instruction[11:8]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b110: begin // BLTU
                        seg7 = char_to_seg("B");
                        seg6 = char_to_seg("L");
                        seg5 = char_to_seg("T");
                        seg4 = char_to_seg("U");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(instruction[11:8]));
                        seg0 = char_to_seg(" ");
                    end
                    3'b111: begin // BGEU
                        seg7 = char_to_seg("B");
                        seg6 = char_to_seg("G");
                        seg5 = char_to_seg("E");
                        seg4 = char_to_seg("U");
                        seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                        seg2 = char_to_seg(hex_to_char(rs2[3:0]));
                        seg1 = char_to_seg(hex_to_char(instruction[11:8]));
                        seg0 = char_to_seg(" ");
                    end
                endcase
            end
            
            // JAL
            5'b11011: begin
                seg7 = char_to_seg("J");
                seg6 = char_to_seg("A");
                seg5 = char_to_seg("L");
                seg4 = char_to_seg(" ");
                seg3 = char_to_seg(hex_to_char(rd[3:0]));
                seg2 = char_to_seg(hex_to_char(instruction[23:20])); // imm[19:16]
                seg1 = char_to_seg(hex_to_char(instruction[19:16])); // imm[15:12]
                seg0 = char_to_seg(" ");
            end
            
            // JALR
            5'b11001: begin
                seg7 = char_to_seg("J");
                seg6 = char_to_seg("A");
                seg5 = char_to_seg("L");
                seg4 = char_to_seg("R");
                seg3 = char_to_seg(hex_to_char(rs1[3:0]));
                seg2 = char_to_seg(hex_to_char(instruction[23:20])); // imm
                seg1 = char_to_seg(hex_to_char(rd[3:0]));
                seg0 = char_to_seg(" ");
            end
            
            // LUI
            5'b01101: begin
                seg7 = char_to_seg("L");
                seg6 = char_to_seg("U");
                seg5 = char_to_seg("I");
                seg4 = char_to_seg(" ");
                seg3 = char_to_seg(hex_to_char(instruction[31:28])); // imm[31:28]
                seg2 = char_to_seg(hex_to_char(instruction[27:24])); // imm[27:24]
                seg1 = char_to_seg(hex_to_char(rd[3:0]));
                seg0 = char_to_seg(" ");
            end
            
            // AUIPC
            5'b00101: begin
                seg7 = char_to_seg("A");
                seg6 = char_to_seg("U");
                seg5 = char_to_seg("I");
                seg4 = char_to_seg("P");
                seg3 = char_to_seg("C");
                seg2 = char_to_seg(hex_to_char(instruction[27:24])); // imm
                seg1 = char_to_seg(hex_to_char(rd[3:0]));
                seg0 = char_to_seg(" ");
            end
            
            // Default: show hex
            default: begin
                // Already set to hex at the beginning
            end
        endcase
    end

endmodule
