`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// PS/2 Numpad +/- Key Y-Offset Controller
// 숫자 키패드의 +/- 키를 사용하여 이미지를 32픽셀 단위로 이동
// Numpad +: 아래로 이동 (y_offset 증가)
// Numpad -: 위로 이동 (y_offset 감소)
//////////////////////////////////////////////////////////////////////////////////

module ps2_arrow_scancode (
    input  wire clk,
    input  wire rst,
    input  wire ps2_clk,
    input  wire ps2_data,
    output reg  [7:0] scancode,
    output reg  scancode_ready,
    output reg  is_extended,
    output reg  is_break
);

// PS/2 클럭 동기화 레지스터
reg [2:0] ps2c_sync;
reg [3:0] bit_count;
reg [10:0] shift;

// Extended 코드와 Break 코드
localparam EXTENDED_CODE = 8'hE0;
localparam BREAK_CODE    = 8'hF0;

// 내부 상태
reg extended_flag;
reg break_flag;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ps2c_sync      <= 3'b0;
        bit_count      <= 4'b0;
        shift          <= 11'b0;
        scancode       <= 8'b0;
        scancode_ready <= 1'b0;
        is_extended    <= 1'b0;
        is_break       <= 1'b0;
        extended_flag  <= 1'b0;
        break_flag     <= 1'b0;
    end else begin
        // PS/2 클럭을 시스템 클럭 도메인으로 동기화 (falling edge 검출)
        ps2c_sync <= {ps2c_sync[1:0], ps2_clk};
        scancode_ready <= 1'b0;  // 기본적으로 ready는 0

        // PS/2 클럭의 falling edge 검출 (2'b10)
        if (ps2c_sync[2:1] == 2'b10) begin
            shift[bit_count] <= ps2_data;
            
            if (bit_count == 4'd10) begin
                // 11비트 수신 완료 (start + 8 data + parity + stop)
                bit_count <= 4'd0;
                
                // 수신된 스캔코드 추출 (data bits: shift[8:1])
                if (shift[8:1] == EXTENDED_CODE) begin
                    // Extended 코드 (E0) 수신 - 플래그 설정만
                    extended_flag <= 1'b1;
                end else if (shift[8:1] == BREAK_CODE) begin
                    // Break 코드 (F0) 수신 - 플래그 설정만
                    break_flag <= 1'b1;
                end else begin
                    // 일반 스캔코드 수신 - 출력
                    scancode       <= shift[8:1];
                    scancode_ready <= 1'b1;
                    is_extended    <= extended_flag;
                    is_break       <= break_flag;
                    // 플래그 리셋
                    extended_flag  <= 1'b0;
                    break_flag     <= 1'b0;
                end
            end else begin
                bit_count <= bit_count + 1'b1;
            end
        end
    end
end
endmodule


//////////////////////////////////////////////////////////////////////////////////
// 숫자 키패드 +/- 키 기반 Y-Offset 컨트롤러
// Numpad + (79): 아래로 이동 (y_offset 증가)
// Numpad - (7B): 위로 이동 (y_offset 감소)
//////////////////////////////////////////////////////////////////////////////////

module arrow_key_yoffset_ctrl #(
    parameter MAX_STEP = 4'd14  // 14 * 32 = 448 pixels, 480p에 맞춤
)(
    input  wire clk,
    input  wire rst,
    input  wire [7:0] scancode,
    input  wire scancode_ready,
    input  wire is_extended,
    input  wire is_break,
    output reg  [3:0] y_offset
);

// 숫자 키패드 스캔코드 (Extended 코드 아님, 일반 스캔코드)
localparam SC_NUMPAD_PLUS  = 8'h79;  // Numpad +
localparam SC_NUMPAD_MINUS = 8'h7B;  // Numpad -

always @(posedge clk or posedge rst) begin
    if (rst) begin
        y_offset <= 4'd0;
    end else begin
        // Make 코드(눌림)일 때만 처리 (Extended 여부 상관없음)
        if (scancode_ready && !is_break) begin
            case (scancode)
                SC_NUMPAD_MINUS: begin
                    // 위로 이동 = y_offset 감소
                    if (y_offset > 0)
                        y_offset <= y_offset - 1'b1;
                end
                SC_NUMPAD_PLUS: begin
                    // 아래로 이동 = y_offset 증가
                    if (y_offset < MAX_STEP)
                        y_offset <= y_offset + 1'b1;
                end
                default: ;  // 다른 키는 무시
            endcase
        end
    end
end
endmodule


//////////////////////////////////////////////////////////////////////////////////
// PS/2 Numpad +/- Key Y-Offset Top Module
// 전체를 통합하는 상위 모듈
//////////////////////////////////////////////////////////////////////////////////

module ps2_arrow_yoffset_top #(
    parameter MAX_STEP = 4'd14
)(
    input  wire clk,
    input  wire rst,
    input  wire ps2_clk,
    input  wire ps2_data,
    output wire [3:0] y_offset,
    output wire [7:0] debug_scancode,
    output wire debug_ready
);

wire [7:0] scancode;
wire scancode_ready;
wire is_extended;
wire is_break;

// PS/2 스캔코드 디코더
ps2_arrow_scancode scanner (
    .clk(clk),
    .rst(rst),
    .ps2_clk(ps2_clk),
    .ps2_data(ps2_data),
    .scancode(scancode),
    .scancode_ready(scancode_ready),
    .is_extended(is_extended),
    .is_break(is_break)
);

// 숫자 키패드 +/- 키 Y-Offset 컨트롤러
arrow_key_yoffset_ctrl #(
    .MAX_STEP(MAX_STEP)
) offset_ctrl (
    .clk(clk),
    .rst(rst),
    .scancode(scancode),
    .scancode_ready(scancode_ready),
    .is_extended(is_extended),
    .is_break(is_break),
    .y_offset(y_offset)
);

// 디버그 출력
assign debug_scancode = scancode;
assign debug_ready = scancode_ready;

endmodule
