`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: top.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   최상위 모듈. RISC-V CPU 코어와 I/O 장치들을 통합.
//   
// I/O 구성:
//   - PS2 키보드: 숫자 입력 (0-9, Enter, Backspace)
//   - 7-Segment Display: 입력 중인 숫자 표시 (8자리)
//   - VGA: ODD/EVEN 결과 표시
//   - LED[0]: Heartbeat (시스템 동작 확인)
//   - LED[15:1]: 결과 표시 (홀수=ON, 짝수=OFF)
//
// Change History:
//   2024.12.11 - PS2 + VGA 통합, UART 제거
//////////////////////////////////////////////////////////////////////////////////

module top(
    // ===== 시스템 =====
    input wire clk,              // 100 MHz 시스템 클럭
    input wire rst,              // Active-Low 리셋 (CPU_RESET 버튼)
    
    // ===== 스위치 =====
    input wire switch_0,         // 7-Segment 모드 선택 (0: 숫자, 1: PC)
    
    // ===== PS2 키보드 =====
    input wire ps2_clk,          // PS2 클럭
    input wire ps2_data,         // PS2 데이터
    
    // ===== VGA =====
    output wire vga_hsync,       // Horizontal sync
    output wire vga_vsync,       // Vertical sync
    output wire [3:0] vga_r,     // Red
    output wire [3:0] vga_g,     // Green
    output wire [3:0] vga_b,     // Blue
    
    // ===== 7-Segment =====
    output wire [6:0] seg_out,   // Cathodes (a-g)
    output wire [7:0] seg_sel,   // Anodes (8 digits)
    
    // ===== LED =====
    output wire led_heartbeat,   // LED[0]: Heartbeat
    output wire [15:0] led       // LED[15:1]: 결과 표시
);

    // =========================================================================
    // Clocking Wizard (100 MHz → 50 MHz for CPU)
    // =========================================================================
    wire clk_cpu;           // 50 MHz CPU 클럭
    wire clk_locked;        // PLL 잠금 신호
    
    clk_wiz_0 clk_gen (
        .clk_in1(clk),      // 100 MHz 입력
        .clk_out1(clk_cpu), // 50 MHz 출력 (CPU용)
        .reset(~rst),       // Active-high reset
        .locked(clk_locked)
    );
    
    // 시스템 리셋: 외부 리셋 OR PLL 미잠금
    wire sys_rst = rst & clk_locked;

    // =========================================================================
    // 내부 신호
    // =========================================================================
    
    // CPU 신호
    wire [31:0] inst_out, PC;
    wire [15:0] led_reg;
    
    // PS2 키보드 신호
    wire [7:0] ps2_scancode;
    wire ps2_released;
    wire ps2_key_pressed;
    wire ps2_err;
    
    // 숫자 버퍼 신호
    wire [31:0] input_number;
    wire number_valid;
    wire [3:0] digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7;
    
    // VGA 신호
    wire [9:0] pixel_x, pixel_y;
    wire video_on, pixel_clk;
    wire [1:0] vga_result;       // CPU → VGA (MMIO)
    
    // CPU 디버그 신호 (data_path 호환용)
    wire branch, mem_read, mem_to_reg, mem_write, alu_src, reg_write;
    wire [1:0] alu_op;
    wire z_flag;
    wire [4:0] alu_ctrl_out;
    wire [31:0] PC_inc, PC_gen_out, PC_in;
    wire [31:0] data_read_1, data_read_2, write_data, imm_out, shift, alu_mux, alu_out, data_mem_out;
    
    // =========================================================================
    // CPU Core (data_path)
    // =========================================================================
    data_path dp(
        .clk(clk_cpu),
        .rst(sys_rst),
        .inst_out_ext(inst_out),
        .branch_ext(branch),
        .mem_read_ext(mem_read),
        .mem_to_reg_ext(mem_to_reg),
        .mem_write_ext(mem_write),
        .alu_src_ext(alu_src),
        .reg_write_ext(reg_write),
        .alu_op_ext(alu_op),
        .z_flag_ext(z_flag),
        .alu_ctrl_out_ext(alu_ctrl_out),
        .PC_inc_ext(PC_inc),
        .pc_gen_out_ext(PC_gen_out),
        .PC_ext(PC),
        .PC_in_ext(PC_in),
        .data_read_1_ext(data_read_1),
        .data_read_2_ext(data_read_2),
        .write_data_ext(write_data),
        .imm_out_ext(imm_out),
        .shift_ext(shift),
        .alu_mux_ext(alu_mux),
        .alu_out_ext(alu_out),
        .data_mem_out_ext(data_mem_out),
        .led_reg_out(led_reg),
        // PS2 Keyboard (새로 추가)
        .ps2_scancode_in(ps2_scancode),
        .ps2_key_pressed_in(ps2_key_pressed),
        // Number Buffer (새로 추가)
        .num_buffer_in(input_number),
        .num_valid_in(number_valid),
        // VGA Result (새로 추가)
        .vga_result_out(vga_result)
    );
    
    // =========================================================================
    // PS2 Keyboard Controller
    // =========================================================================
    ps2_kbd_top ps2_kbd(
        .clk(clk_cpu),
        .rst(!sys_rst),  // ps2_kbd_top은 active-high reset 사용
        .ps2clk(ps2_clk),
        .ps2data(ps2_data),
        .scancode(ps2_scancode),
        .Released(ps2_released),
        .err_ind(ps2_err)
    );
    
    // 키 눌림 감지 (released의 falling edge = 키 눌림)
    reg ps2_released_d;
    always @(posedge clk_cpu) begin
        if (!sys_rst)
            ps2_released_d <= 1'b1;
        else
            ps2_released_d <= ps2_released;
    end
    assign ps2_key_pressed = ps2_released_d && !ps2_released;  // Falling edge
    
    // =========================================================================
    // Number Input Buffer
    // =========================================================================
    number_input_buffer num_buf(
        .clk(clk_cpu),
        .rst(!sys_rst),
        .scancode(ps2_scancode),
        .key_pressed(ps2_key_pressed),
        .cpu_read_ack(1'b0),  // TODO: CPU에서 읽음 신호 연결
        .number(input_number),
        .number_valid(number_valid),
        .digit0(digit0),
        .digit1(digit1),
        .digit2(digit2),
        .digit3(digit3),
        .digit4(digit4),
        .digit5(digit5),
        .digit6(digit6),
        .digit7(digit7)
    );
    
    // =========================================================================
    // VGA Controller
    // =========================================================================
    vga_controller vga_ctrl(
        .clk(clk),
        .reset(!rst),
        .hsync(vga_hsync),
        .vsync(vga_vsync),
        .video_on(video_on),
        .pixel_clk(pixel_clk),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );
    
    // =========================================================================
    // VGA Text Display (ODD/EVEN)
    // =========================================================================
    vga_text_display vga_text(
        .clk(clk),
        .rst(!rst),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .video_on(video_on),
        .result(vga_result),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );
    
    // =========================================================================
    // 7-Segment Display
    // =========================================================================
    // BCD to 7-segment 변환 함수
    function [6:0] bcd_to_seg;
        input [3:0] bcd;
        begin
            case (bcd)
                4'd0: bcd_to_seg = 7'b1000000;
                4'd1: bcd_to_seg = 7'b1111001;
                4'd2: bcd_to_seg = 7'b0100100;
                4'd3: bcd_to_seg = 7'b0110000;
                4'd4: bcd_to_seg = 7'b0011001;
                4'd5: bcd_to_seg = 7'b0010010;
                4'd6: bcd_to_seg = 7'b0000010;
                4'd7: bcd_to_seg = 7'b1111000;
                4'd8: bcd_to_seg = 7'b0000000;
                4'd9: bcd_to_seg = 7'b0010000;
                default: bcd_to_seg = 7'b1111111;  // Blank
            endcase
        end
    endfunction
    
    // 7-Segment 패턴 생성
    wire [6:0] seg0_pattern = bcd_to_seg(digit0);
    wire [6:0] seg1_pattern = bcd_to_seg(digit1);
    wire [6:0] seg2_pattern = bcd_to_seg(digit2);
    wire [6:0] seg3_pattern = bcd_to_seg(digit3);
    wire [6:0] seg4_pattern = bcd_to_seg(digit4);
    wire [6:0] seg5_pattern = bcd_to_seg(digit5);
    wire [6:0] seg6_pattern = bcd_to_seg(digit6);
    wire [6:0] seg7_pattern = bcd_to_seg(digit7);
    
    // Leading zero suppression (선행 0 제거)
    wire [6:0] s7 = (digit7 == 0) ? 7'b1111111 : seg7_pattern;
    wire [6:0] s6 = (digit7 == 0 && digit6 == 0) ? 7'b1111111 : seg6_pattern;
    wire [6:0] s5 = (digit7 == 0 && digit6 == 0 && digit5 == 0) ? 7'b1111111 : seg5_pattern;
    wire [6:0] s4 = (digit7 == 0 && digit6 == 0 && digit5 == 0 && digit4 == 0) ? 7'b1111111 : seg4_pattern;
    wire [6:0] s3 = (digit7 == 0 && digit6 == 0 && digit5 == 0 && digit4 == 0 && digit3 == 0) ? 7'b1111111 : seg3_pattern;
    wire [6:0] s2 = (digit7 == 0 && digit6 == 0 && digit5 == 0 && digit4 == 0 && digit3 == 0 && digit2 == 0) ? 7'b1111111 : seg2_pattern;
    wire [6:0] s1 = (digit7 == 0 && digit6 == 0 && digit5 == 0 && digit4 == 0 && digit3 == 0 && digit2 == 0 && digit1 == 0) ? 7'b1111111 : seg1_pattern;
    wire [6:0] s0 = seg0_pattern;  // 일의 자리는 항상 표시
    
    // 7-Segment Driver
    seven_segment_8_driver seg_driver(
        .clk(clk_cpu),
        .rst(!sys_rst),
        .seg0(s0),
        .seg1(s1),
        .seg2(s2),
        .seg3(s3),
        .seg4(s4),
        .seg5(s5),
        .seg6(s6),
        .seg7(s7),
        .seg_out(seg_out),
        .seg_sel(seg_sel)
    );
    
    // =========================================================================
    // Heartbeat LED (시스템 동작 확인)
    // =========================================================================
    reg [24:0] heartbeat_counter;  // 50MHz로 변경으로 25비트로 조정
    
    always @(posedge clk_cpu) begin
        if (!sys_rst)
            heartbeat_counter <= 25'd0;
        else
            heartbeat_counter <= heartbeat_counter + 1'b1;
    end
    
    assign led_heartbeat = heartbeat_counter[24];  // ~1.5 Hz @ 50MHz
    
    // =========================================================================
    // LED 출력 (CPU 제어)
    // =========================================================================
    assign led = led_reg;

endmodule
