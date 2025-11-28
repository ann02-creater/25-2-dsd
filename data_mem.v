`timescale 1ns / 1ps
module DataMem (
    input clk, input MemRead, input MemWrite,
    input [31:0] addr, input [2:0] func3, input [31:0] data_in,
    output reg [31:0] data_out,
    output reg [15:0] led_reg, output reg [7:0] uart_tx_data, 
    output reg uart_tx_we, output reg uart_rx_re,
    input [7:0] uart_rx_data, input uart_rx_valid, input uart_tx_busy
);
    // --------------------------------------------------------
    // 1. 순수 메모리 영역 (BRAM 추론 유도)
    // --------------------------------------------------------
    reg [7:0] mem [0:4095]; 
    initial $readmemh("C:/FPGA_Project/sw/game.hex", mem); // 경로 확인!

    // 주소 디코딩 (0x00000000 ~ 0x00000FFF는 메모리 영역)
    wire is_mmio = (addr[31:12] != 20'h00000); 
    wire mem_we  = MemWrite & !is_mmio;        // 메모리 쓰기 신호
    
    // 4바이트 정렬 주소
    wire [11:0] aligned_addr = {addr[11:2], 2'b00};

    // ★ 중요: 메모리 전용 Always 블록 (이렇게 분리해야 BRAM으로 잡힘) ★
    always @(posedge clk) begin
        if (mem_we) begin
            if (func3 == 3'b010) begin // SW
                mem[aligned_addr]   <= data_in[7:0];
                mem[aligned_addr+1] <= data_in[15:8];
                mem[aligned_addr+2] <= data_in[24:16];
                mem[aligned_addr+3] <= data_in[31:24];
            end
            else if (func3 == 3'b001) begin // SH
                mem[addr[11:0]]   <= data_in[7:0];
                mem[addr[11:0]+1] <= data_in[15:8];
            end
            else if (func3 == 3'b000) begin // SB
                mem[addr[11:0]] <= data_in[7:0];
            end
        end
    end

    // --------------------------------------------------------
    // 2. MMIO 및 읽기 로직 (조합 회로 + 레지스터)
    // --------------------------------------------------------
    always @(posedge clk) begin
        uart_tx_we <= 0; // Pulse 초기화
        if (MemWrite) begin
            if (addr == 32'h2000_0000) led_reg <= data_in[15:0];
            else if (addr == 32'h1000_0000) begin 
                uart_tx_data <= data_in[7:0]; 
                uart_tx_we <= 1'b1; 
            end
        end
    end

    always @(*) begin
        uart_rx_re = 0; data_out = 32'b0;
        if (MemRead) begin
            // MMIO 읽기
            if (addr == 32'h1000_0000) begin data_out = {24'b0, uart_rx_data}; uart_rx_re = 1'b1; end
            else if (addr == 32'h1000_0004) data_out = {30'b0, uart_tx_busy, uart_rx_valid};
            // 메모리 읽기 (BRAM에서 읽어옴)
            else begin
                if (func3 == 3'b010)      data_out = {mem[aligned_addr+3], mem[aligned_addr+2], mem[aligned_addr+1], mem[aligned_addr]};
                else if (func3 == 3'b001) data_out = {{16{mem[addr[11:0]+1][7]}}, mem[addr[11:0]+1], mem[addr[11:0]]};
                else if (func3 == 3'b101) data_out = {16'b0, mem[addr[11:0]+1], mem[addr[11:0]]};
                else if (func3 == 3'b100) data_out = {24'b0, mem[addr[11:0]]};
                else if (func3 == 3'b000) data_out = {{24{mem[addr[11:0]][7]}}, mem[addr[11:0]]};
            end
        end
    end
endmodule
