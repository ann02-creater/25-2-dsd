`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: number_input_buffer.v
// Project: RISC-V 5-Stage Pipeline Processor - Odd/Even Game
// Author: 22400387 송해원
//
// Description:
//   PS2 키보드로부터 숫자를 입력받아 버퍼에 저장하는 모듈.
//   곱셈/나눗셈 연산을 제거하여 100MHz 타이밍 충족.
//   
//   BCD 직접 저장 방식:
//   - 각 자릿수를 4비트 BCD로 분리 저장
//   - 숫자 입력: 왼쪽으로 shift 후 새 숫자 추가
//   - Backspace: 오른쪽으로 shift
//   - Binary 변환은 CPU 읽기 시에만 수행 (느린 경로)
//
// Interface with CPU (Memory-Mapped I/O):
//   0x50000000 (READ): 입력된 숫자 값 (32-bit binary)
//   0x50000004 (READ): 입력 완료 플래그 (bit 0 = number_valid)
//
// Change History:
//   2024.12.12 - 타이밍 최적화: 곱셈 연산 제거, BCD 직접 저장
//////////////////////////////////////////////////////////////////////////////////

module number_input_buffer(
    input wire clk,
    input wire rst,
    
    // PS2 키보드 인터페이스
    input wire [7:0] scancode,     // PS2에서 변환된 ASCII 코드
    input wire key_pressed,        // 키가 눌림 (edge-detected)
    
    // CPU 인터페이스 (MMIO)
    input wire cpu_read_ack,       // CPU가 값을 읽었음을 알림
    
    // 출력
    output reg [31:0] number,      // 입력된 숫자 (binary, BCD→Binary 변환 후)
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
    
    // =========================================================================
    // BCD 저장 (8자리, 각 4비트)
    // =========================================================================
    reg [3:0] bcd [0:7];  // bcd[0]=일의 자리, bcd[7]=천만의 자리
    reg [2:0] digit_count; // 현재 입력된 자릿수 (0-8)
    
    // 숫자 키 감지
    wire is_digit = (scancode >= ASCII_0) && (scancode <= ASCII_9);
    wire [3:0] digit_value = scancode[3:0];  // ASCII '0'-'9' → 0-9
    
    // 상태 머신
    localparam S_IDLE  = 2'b00;
    localparam S_INPUT = 2'b01;
    localparam S_DONE  = 2'b10;
    
    reg [1:0] state;
    
    // =========================================================================
    // BCD 입력 로직 (곱셈 없음!)
    // =========================================================================
    always @(posedge clk) begin
        if (rst) begin
            bcd[0] <= 4'd0; bcd[1] <= 4'd0; bcd[2] <= 4'd0; bcd[3] <= 4'd0;
            bcd[4] <= 4'd0; bcd[5] <= 4'd0; bcd[6] <= 4'd0; bcd[7] <= 4'd0;
            digit_count <= 3'd0;
            number_valid <= 1'b0;
            state <= S_IDLE;
        end
        else begin
            case (state)
                S_IDLE, S_INPUT: begin
                    if (key_pressed) begin
                        if (is_digit && digit_count < 8) begin
                            // 숫자 키: BCD 왼쪽 shift 후 새 숫자 추가
                            bcd[7] <= bcd[6];
                            bcd[6] <= bcd[5];
                            bcd[5] <= bcd[4];
                            bcd[4] <= bcd[3];
                            bcd[3] <= bcd[2];
                            bcd[2] <= bcd[1];
                            bcd[1] <= bcd[0];
                            bcd[0] <= digit_value;
                            digit_count <= digit_count + 1'b1;
                            state <= S_INPUT;
                        end
                        else if (scancode == ASCII_BS && digit_count > 0) begin
                            // Backspace: BCD 오른쪽 shift
                            bcd[0] <= bcd[1];
                            bcd[1] <= bcd[2];
                            bcd[2] <= bcd[3];
                            bcd[3] <= bcd[4];
                            bcd[4] <= bcd[5];
                            bcd[5] <= bcd[6];
                            bcd[6] <= bcd[7];
                            bcd[7] <= 4'd0;
                            digit_count <= digit_count - 1'b1;
                        end
                        else if (scancode == ASCII_ENTER && digit_count > 0) begin
                            // Enter: 입력 완료
                            number_valid <= 1'b1;
                            state <= S_DONE;
                        end
                    end
                end
                
                S_DONE: begin
                    // CPU가 값을 읽으면 다음 입력 준비
                    if (cpu_read_ack) begin
                        bcd[0] <= 4'd0; bcd[1] <= 4'd0; bcd[2] <= 4'd0; bcd[3] <= 4'd0;
                        bcd[4] <= 4'd0; bcd[5] <= 4'd0; bcd[6] <= 4'd0; bcd[7] <= 4'd0;
                        digit_count <= 3'd0;
                        number_valid <= 1'b0;
                        state <= S_IDLE;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
    
    // =========================================================================
    // number 출력 (CPU용)
    // =========================================================================
    // 홀짝 게임에서 필요한 것은 홀수/짝수 판단만!
    // bcd[0]의 최하위 비트가 1이면 홀수, 0이면 짝수
    // number[0] = bcd[0][0] (홀짝 판단용)
    // number[31:1] = 0 (사용 안함)
    
    // 또는 간단하게: 하위 4자리 BCD를 합쳐서 출력 (최대 9999)
    // 이러면 곱셈이 필요 없음
    always @(posedge clk) begin
        if (rst) begin
            number <= 32'd0;
        end
        else begin
            // 간단한 방식: BCD 그대로 합쳐서 출력 (곱셈 없음)
            // number = {bcd[7], bcd[6], bcd[5], bcd[4], bcd[3], bcd[2], bcd[1], bcd[0]}
            number <= {bcd[7], bcd[6], bcd[5], bcd[4], bcd[3], bcd[2], bcd[1], bcd[0]};
        end
    end
    
    // =========================================================================
    // BCD 출력 (7-Segment 표시용)
    // =========================================================================
    assign digit0 = bcd[0];
    assign digit1 = bcd[1];
    assign digit2 = bcd[2];
    assign digit3 = bcd[3];
    assign digit4 = bcd[4];
    assign digit5 = bcd[5];
    assign digit6 = bcd[6];
    assign digit7 = bcd[7];

endmodule
