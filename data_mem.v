`timescale 1ns / 1ps
module DataMem (
    input clk,
    input MemRead,
    input MemWrite,
    input [31:0] addr,
    input [2:0] func3,
    input [31:0] data_in,
    output reg [31:0] data_out,
    
    // [외부 연결 포트]
    output reg [15:0] led_reg,       // LED 제어
    output reg [7:0]  uart_tx_data,  // UART 송신 데이터
    output reg        uart_tx_we,    // UART 송신 신호
    output reg        uart_rx_re,    // UART 수신 확인 신호
    input  [7:0]      uart_rx_data,  // UART 수신 데이터
    input             uart_rx_valid, // UART 수신 완료 플래그
    input             uart_tx_busy   // UART 송신 중 플래그
);

    reg [7:0] mem [0:4095]; 

    initial begin
        led_reg = 0;
        uart_tx_we = 0;
        uart_rx_re = 0;
        // ★★★ Hex 파일 경로 본인 환경에 맞게 수정 필수! ★★★
        $readmemh("C:/Users/User/Desktop/game.hex", mem); 
    end

    // 쓰기 동작 (Write)
    always @(posedge clk) begin
        // 기본값 초기화 (Pulse 신호)
        uart_tx_we <= 0;

        if (MemWrite & ~MemRead) begin
            // 1. LED 제어 (0x20000000)
            if (addr == 32'h2000_0000) begin
                led_reg <= data_in[15:0];
            end
            // 2. UART 송신 (0x10000000)
            else if (addr == 32'h1000_0000) begin
                uart_tx_data <= data_in[7:0];
                uart_tx_we <= 1'b1; // 1 클럭 동안만 High
            end
            // 3. 일반 메모리 쓰기
            else begin
                if (func3 == 3'b010) begin // SW
                    mem[addr] <= data_in[7:0];
                    mem[addr+1]<=data_in[15:8];
                    mem[addr+2]<=data_in[24:16];
                    mem[addr+3]<=data_in[31:24];
                end
                else if (func3 == 3'b001) begin // SH
                    mem[addr] <= data_in[7:0];
                    mem[addr+1] <= data_in[15:8];
                end
                else if (func3==3'b000) begin // SB
                    mem[addr] <= data_in[7:0];
                end
            end
        end
    end

    // 읽기 동작 (Read)
    always @(*) begin
        // 기본값
        uart_rx_re = 0; 
        data_out = 32'b0;

        if (MemRead & ~MemWrite) begin
            // 1. UART 데이터 읽기 (0x10000000) - 읽으면 수신 버퍼 비움
            if (addr == 32'h1000_0000) begin
                data_out = {24'b0, uart_rx_data};
                uart_rx_re = 1'b1; // 읽었음을 알림
            end
            // 2. UART 상태 읽기 (0x10000004) - [1]:Busy, [0]:Valid
            else if (addr == 32'h1000_0004) begin
                data_out = {30'b0, uart_tx_busy, uart_rx_valid};
            end
            // 3. 일반 메모리 읽기
            else begin
                if (func3 == 3'b010)      data_out={mem[addr+3],mem[addr+2],mem[addr+1],mem[addr]};
                else if (func3 == 3'b001) data_out={{16{mem[addr+1][7]}},mem[addr+1],mem[addr]};
                else if (func3 == 3'b101) data_out= {16'b0,mem[addr],mem[addr+1]};
                else if (func3 == 3'b100) data_out= {24'b0,mem[addr]};
                else if (func3 == 3'b000) data_out={{24{mem[addr][7]}},mem[addr]};
            end
        end
    end
endmodule
