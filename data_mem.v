`timescale 1ns / 1ps
module DataMem (
    input clk,
    input MemRead,
    input MemWrite,
    input [31:0] addr,
    input [2:0] func3,
    input [31:0] data_in,
    output reg [31:0] data_out,
    
    // 외부 포트
    output reg [15:0] led_reg,
    output reg [7:0]  uart_tx_data,
    output reg        uart_tx_we,
    output reg        uart_rx_re,
    input  [7:0]      uart_rx_data,
    input             uart_rx_valid,
    input             uart_tx_busy
);

    reg [7:0] mem [0:4095]; 

    initial begin
        led_reg = 0;
        uart_tx_we = 0;
        uart_rx_re = 0;
        // ★ 경로 확인 필수 ★
        $readmemh("C:/FPGA_Project/sw/game.hex", mem); 
    end

    // [핵심 수정] 주소의 하위 2비트를 버려서 '4의 배수'로 강제 정렬
    wire [31:0] aligned_addr = {addr[31:2], 2'b00};

    // 쓰기 동작
    always @(posedge clk) begin
        uart_tx_we <= 0;

        if (MemWrite & ~MemRead) begin
            // MMIO 처리
            if (addr == 32'h2000_0000)      led_reg <= data_in[15:0];
            else if (addr == 32'h1000_0000) begin
                uart_tx_data <= data_in[7:0];
                uart_tx_we <= 1'b1;
            end
            // 메모리 쓰기
            else begin
                // SW (Word) - 4바이트 한번에 쓰기
                if (func3 == 3'b010) begin 
                    mem[aligned_addr]   <= data_in[7:0];
                    mem[aligned_addr+1] <= data_in[15:8];
                    mem[aligned_addr+2] <= data_in[24:16];
                    mem[aligned_addr+3] <= data_in[31:24];
                end
                // SH (Half)
                else if (func3 == 3'b001) begin 
                    mem[addr]   <= data_in[7:0];
                    mem[addr+1] <= data_in[15:8];
                end
                // SB (Byte)
                else if (func3 == 3'b000) begin 
                    mem[addr] <= data_in[7:0];
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
            // 메모리 읽기 (Word Aligned!)
            else begin
                // [핵심 수정] addr 대신 aligned_addr 사용 -> Vivado가 4개의 Bank로 인식하여 최적화함
                if (func3 == 3'b010)      
                    data_out = {mem[aligned_addr+3], mem[aligned_addr+2], mem[aligned_addr+1], mem[aligned_addr]};
                else if (func3 == 3'b001) // LH
                    data_out = {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};
                else if (func3 == 3'b101) // LHU
                    data_out = {16'b0, mem[addr+1], mem[addr]};
                else if (func3 == 3'b100) // LBU
                    data_out = {24'b0, mem[addr]};
                else if (func3 == 3'b000) // LB
                    data_out = {{24{mem[addr][7]}}, mem[addr]};
            end
        end
    end
endmodule
