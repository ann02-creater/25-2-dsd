`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: number_input_buffer.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   PS2 키보드로부터 숫자를 입력받아 버퍼에 저장하는 모듈.
//   - 숫자 키 (0-9): 현재 값에 10을 곱하고 새 숫자 추가
//   - Backspace: 마지막 숫자 삭제 (10으로 나누기)
//   - Enter: 입력 완료 신호 발생, CPU가 값을 읽을 수 있음
//   - 최대 8자리 (99,999,999) 까지 지원
//
// Interface with CPU (Memory-Mapped I/O):
//   0x50000000 (READ): 입력된 숫자 값 (32-bit)
//   0x50000004 (READ): 입력 완료 플래그 (bit 0 = number_valid)
//
// Change History:
//   2024.12.11 - Initial creation
//////////////////////////////////////////////////////////////////////////////////

module number_input_buffer(
    input wire clk,
    input wire rst,
    
    // PS2 키보드 인터페이스
    input wire [7:0] scancode,     // PS2에서 변환된 ASCII 코드
    input wire key_pressed,        // 키가 눌림 (edge-detected)
    
    // CPU 인터페이스 (MMIO)
    input wire cpu_read_ack,       // CPU가 값을 읽었음을 알림 (valid 클리어용)
    
    // 출력
    output reg [31:0] number,      // 입력된 숫자 (최대 99,999,999)
    output reg number_valid,       // Enter 눌림, CPU가 읽어야 함
    
    // 7-Segment 디스플레이용 BCD 출력 (8자리)
    output wire [3:0] digit0,      // 일의 자리
    output wire [3:0] digit1,      // 십의 자리
    output wire [3:0] digit2,      // 백의 자리
    output wire [3:0] digit3,      // 천의 자리
    output wire [3:0] digit4,      // 만의 자리
    output wire [3:0] digit5,      // 십만의 자리
    output wire [3:0] digit6,      // 백만의 자리
    output wire [3:0] digit7       // 천만의 자리
);

    // ASCII 코드 정의
    localparam ASCII_0     = 8'h30;  // '0'
    localparam ASCII_9     = 8'h39;  // '9'
    localparam ASCII_ENTER = 8'h0D;  // Enter
    localparam ASCII_BS    = 8'h08;  // Backspace
    
    // 최대값 제한 (8자리 = 99,999,999)
    localparam MAX_VALUE = 32'd99999999;
    
    // 숫자 키 감지
    wire is_digit = (scancode >= ASCII_0) && (scancode <= ASCII_9);
    wire [3:0] digit_value = scancode[3:0];  // ASCII '0'-'9' → 0-9
    
    // 상태 머신
    localparam S_IDLE  = 2'b00;  // 입력 대기
    localparam S_INPUT = 2'b01;  // 숫자 입력 중
    localparam S_DONE  = 2'b10;  // Enter 눌림, CPU 대기
    
    reg [1:0] state;
    
    // 메인 로직
    always @(posedge clk) begin
        if (rst) begin
            number <= 32'd0;
            number_valid <= 1'b0;
            state <= S_IDLE;
        end
        else begin
            case (state)
                S_IDLE, S_INPUT: begin
                    if (key_pressed) begin
                        if (is_digit) begin
                            // 숫자 키: number = number * 10 + digit
                            if (number <= (MAX_VALUE - digit_value) / 10) begin
                                number <= number * 10 + digit_value;
                            end
                            // 오버플로우 시 무시
                            state <= S_INPUT;
                        end
                        else if (scancode == ASCII_BS) begin
                            // Backspace: 마지막 숫자 삭제
                            number <= number / 10;
                        end
                        else if (scancode == ASCII_ENTER) begin
                            // Enter: 입력 완료
                            number_valid <= 1'b1;
                            state <= S_DONE;
                        end
                    end
                end
                
                S_DONE: begin
                    // CPU가 값을 읽으면 다음 입력 준비
                    if (cpu_read_ack) begin
                        number <= 32'd0;
                        number_valid <= 1'b0;
                        state <= S_IDLE;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
    
    // =========================================================================
    // Binary to BCD 변환 (Double Dabble Algorithm - Combinational)
    // =========================================================================
    // 32-bit binary → 8-digit BCD (각 4-bit)
    
    reg [31:0] bin_temp;
    reg [31:0] bcd;
    integer i;
    
    always @(*) begin
        bin_temp = number;
        bcd = 32'd0;
        
        // Double Dabble: 32번 shift하면서 BCD 보정
        for (i = 0; i < 32; i = i + 1) begin
            // 각 BCD 자릿수가 5 이상이면 3 더하기
            if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
            if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
            if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
            if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
            if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
            if (bcd[23:20] >= 5) bcd[23:20] = bcd[23:20] + 3;
            if (bcd[27:24] >= 5) bcd[27:24] = bcd[27:24] + 3;
            if (bcd[31:28] >= 5) bcd[31:28] = bcd[31:28] + 3;
            
            // Shift left
            bcd = {bcd[30:0], bin_temp[31]};
            bin_temp = {bin_temp[30:0], 1'b0};
        end
    end
    
    // BCD 출력 할당
    assign digit0 = bcd[3:0];
    assign digit1 = bcd[7:4];
    assign digit2 = bcd[11:8];
    assign digit3 = bcd[15:12];
    assign digit4 = bcd[19:16];
    assign digit5 = bcd[23:20];
    assign digit6 = bcd[27:24];
    assign digit7 = bcd[31:28];

endmodule
