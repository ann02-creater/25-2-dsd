`timescale 1ns / 1ps
module DataMem (
    input clk,
    input MemRead,
    input MemWrite,
    input [31:0] addr, // 입력은 32비트지만...
    input [2:0] func3,
    input [31:0] data_in,
    output reg [31:0] data_out,
    
    // 외부 연결 포트
    output reg [15:0] led_reg,
    output reg [7:0]  uart_tx_data,
    output reg        uart_tx_we,
    output reg        uart_rx_re,
    input  [7:0]      uart_rx_data,
    input             uart_rx_valid,
    input             uart_tx_busy
);

    reg [7:0] mem [0:4095]; // 4KB 메모리

    initial begin
        led_reg = 0;
        uart_tx_we = 0;
        uart_rx_re = 0;
        // ★ 경로 확인 필수 ★
        $readmemh("C:/FPGA_Project/sw/game.hex", mem); 
    end

    // [핵심 수정 1] 32비트 주소에서 실제 메모리 크기(4KB=12bit)에 해당하는 하위 비트만 잘라냄
    wire [11:0] mem_addr = addr[11:0]; 
    
    // [핵심 수정 2] 4바이트 정렬을 위해 하위 2비트를 00으로 만듦 (Word Alignment)
    wire [11:0] aligned_addr = {mem_addr[11:2], 2'b00};

    // 쓰기 동작
    always @(posedge clk) begin
        uart_tx_we <= 0;

        if (MemWrite & ~MemRead) begin
            // MMIO 처리 (여기는 32비트 전체 주소 확인)
            if (addr == 32'h2000_0000)      led_reg <= data_in[15:0];
            else if (addr == 32'h1000_0000) begin
                uart_tx_data <= data_in[7:0];
                uart_tx_we <= 1'b1;
            end
            // 메모리 쓰기 (여기는 잘라낸 12비트 주소 사용 -> BRAM 추론 성공!)
            else begin
                if (func3 == 3'b010) begin // SW
                    mem[aligned_addr]   <= data_in[7:0];
                    mem[aligned_addr+1] <= data_in[15:8];
                    mem[aligned_addr+2] <= data_in[24:16];
                    mem[aligned_addr+3] <= data_in[31:24];
                end
                else if (func3 == 3'b001) begin // SH
                    mem[mem_addr]   <= data_in[7:0];
                    mem[mem_addr+1] <= data_in[15:8];
                end
                else if (func3 == 3'b000) begin // SB
                    mem[mem_addr] <= data_in[7:0];
                end
            end
        end
    end

    // 읽기 동작
    always @(*) begin
        uart_rx_re = 0;
        data_out = 32'b0;

        if (MemRead & ~MemWrite) begin
            // MMIO 읽기
            if (addr == 32'h1000_0000) begin
                data_out = {24'b0, uart_rx_data};
                uart_rx_re = 1'b1;
            end
            else if (addr == 32'h1000_0004) begin
                data_out = {30'b0, uart_tx_busy, uart_rx_valid};
            end
            // 메모리 읽기 (잘라낸 12비트 주소 사용)
            else begin
                if (func3 == 3'b010)      
                    data_out = {mem[aligned_addr+3], mem[aligned_addr+2], mem[aligned_addr+1], mem[aligned_addr]};
                else if (func3 == 3'b001) // LH
                    data_out = {{16{mem[mem_addr+1][7]}}, mem[mem_addr+1], mem[mem_addr]};
                else if (func3 == 3'b101) // LHU
                    data_out = {16'b0, mem[mem_addr+1], mem[mem_addr]};
                else if (func3 == 3'b100) // LBU
                    data_out = {24'b0, mem[mem_addr]};
                else if (func3 == 3'b000) // LB
                    data_out = {{24{mem[mem_addr][7]}}, mem[mem_addr]};
            end
        end
    end
endmodule
