`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: mmio_controller.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   Memory-Mapped I/O 컨트롤러.
//   - 주소 디코딩
//   - MMIO Read (lw 명령어 처리)
//   - MMIO Write (sw 명령어 처리)
//
// Memory Map:
//   0x00000000 ~ 0x0FFFFFFF : BRAM
//   0x20000000 : LED Control
//   0x30000000 : PS2 Keyboard Scancode
//   0x30000004 : PS2 Key Pressed
//   0x40000000 : VGA Result Output
//   0x50000000 : Number Input Buffer
//   0x50000004 : Number Valid Flag
//
// Change History:
//   2024.12.12 - data_path.v에서 분리
//////////////////////////////////////////////////////////////////////////////////

module mmio_controller(
    input wire clk,
    input wire rst,
    
    // ===== Memory Access 신호 =====
    input wire mem_write,           // sw 명령어
    input wire [31:0] addr,         // 메모리 주소 (ALU out)
    input wire [31:0] write_data,   // 쓰기 데이터 (RegR2)
    input wire [31:0] bram_data,    // BRAM에서 읽은 데이터
    
    // ===== PS2 Keyboard =====
    input wire [7:0] ps2_scancode,
    input wire ps2_key_pressed,
    
    // ===== Number Buffer =====
    input wire [31:0] num_buffer,
    input wire num_valid,
    
    // ===== 출력 =====
    output reg [31:0] data_out,     // 메모리/MMIO 읽기 결과
    output reg [15:0] led_reg,      // LED 제어 레지스터
    output reg [1:0] vga_result,    // VGA 결과 출력
    
    // ===== BRAM 제어 =====
    output wire is_bram_write       // BRAM 쓰기 enable
);

    // =========================================================================
    // 주소 디코딩
    // =========================================================================
    wire [3:0] addr_hi = addr[31:28];
    
    wire is_bram    = (addr_hi == 4'h0);
    wire is_led     = (addr_hi == 4'h2);
    wire is_ps2     = (addr_hi == 4'h3);
    wire is_vga     = (addr_hi == 4'h4);
    wire is_num_buf = (addr_hi == 4'h5);
    
    // BRAM 쓰기는 BRAM 영역에서만 활성화
    assign is_bram_write = mem_write && is_bram;

    // =========================================================================
    // MMIO Read (lw 명령어)
    // =========================================================================
    always @(*) begin
        case (addr_hi)
            4'h3: begin
                // PS2 Keyboard
                if (addr[3:0] == 4'h0)
                    data_out = {24'b0, ps2_scancode};
                else
                    data_out = {31'b0, ps2_key_pressed};
            end
            4'h5: begin
                // Number Buffer
                if (addr[3:0] == 4'h0)
                    data_out = num_buffer;
                else
                    data_out = {31'b0, num_valid};
            end
            default: data_out = bram_data;
        endcase
    end

    // =========================================================================
    // MMIO Write (sw 명령어)
    // =========================================================================
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            led_reg <= 16'h0;
            vga_result <= 2'b00;
        end
        else if (mem_write) begin
            case (addr_hi)
                4'h2: led_reg <= write_data[15:0];      // LED
                4'h4: vga_result <= write_data[1:0];    // VGA
                default: ; // Nothing
            endcase
        end
    end

endmodule
