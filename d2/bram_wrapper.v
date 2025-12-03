`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module: bram_wrapper
// Project: RISC-V FPGA BRAM Optimization
// Description: Wrapper for Vivado Block Memory Generator IP
//              Provides byte-addressable memory interface for RISC-V processor
//              Handles memory-mapped I/O (UART, LED)
//              Manages 1-cycle BRAM read latency with pipeline registers
//
// Memory Map:
//   0x00000000 - 0x00001FFF: Main memory (8KB BRAM)
//   0x10000000: UART data register (read/write)
//   0x10000004: UART status register (read-only)
//   0x20000000: LED control register (write-only)
//////////////////////////////////////////////////////////////////////////////////

module bram_wrapper (
    input clk,
    input MemRead,
    input MemWrite,
    input [31:0] addr,
    input [2:0] func3,           // Load/Store type (LB/LH/LW/LBU/LHU/SB/SH/SW)
    input [31:0] data_in,
    output reg [31:0] data_out,

    // Memory-mapped I/O ports
    output reg [15:0] led_reg,       // LED control register
    output reg [7:0]  uart_tx_data,  // UART transmit data
    output reg        uart_tx_we,    // UART transmit write enable
    output reg        uart_rx_re,    // UART receive read enable
    input  [7:0]      uart_rx_data,  // UART receive data
    input             uart_rx_valid, // UART receive valid flag
    input             uart_tx_busy,  // UART transmit busy flag

    // BRAM Port A connections (instruction fetch)
    input [10:0] pc_addr,            // PC[12:2] for word addressing
    output [31:0] inst_data          // Instruction data output
);

    // ========================================================================
    // BRAM Interface Signals
    // ========================================================================

    // Port B (Data access) signals
    wire [10:0] bram_addrb;          // Word address for Port B
    wire [3:0] bram_web;             // Byte write enables for Port B
    wire [31:0] bram_dinb;           // Data input for Port B
    wire [31:0] bram_doutb;          // Data output from Port B

    // ========================================================================
    // Pipeline Registers for 1-Cycle BRAM Read Latency
    // ========================================================================

    reg [31:0] addr_pipe;            // Pipelined address
    reg [2:0] func3_pipe;            // Pipelined func3
    reg is_mmio_pipe;                // Pipelined MMIO flag
    reg MemRead_pipe;                // Pipelined MemRead

    always @(posedge clk) begin
        addr_pipe <= addr;
        func3_pipe <= func3;
        is_mmio_pipe <= (addr[31:28] == 4'h1) | (addr[31:28] == 4'h2);
        MemRead_pipe <= MemRead;
    end

    // ========================================================================
    // BRAM IP Instantiation
    // ========================================================================

    // NOTE: This is a placeholder for the actual Vivado IP instantiation
    // You need to generate the Block Memory Generator IP in Vivado with:
    //   - Component Name: blk_mem_gen_0
    //   - Memory Type: True Dual Port RAM
    //   - Port A: Read Only, 32-bit width, 2048 depth
    //   - Port B: Read First, 32-bit width, 2048 depth, Byte Write Enable
    //   - Initialize from game.coe
    //
    // Then uncomment and use the generated instantiation template below:

    /*
    blk_mem_gen_0 bram_inst (
        // Port A (Instruction fetch)
        .clka(~clk),                 // Inverted clock for negedge operation
        .ena(1'b1),                  // Always enabled
        .wea(1'b0),                  // Read-only
        .addra(pc_addr),             // PC word address
        .dina(32'b0),                // Not used (read-only)
        .douta(inst_data),           // Instruction output

        // Port B (Data access)
        .clkb(clk),                  // Positive edge clock
        .enb(MemRead | MemWrite),    // Enable on read or write
        .web(bram_web),              // Byte write enables
        .addrb(bram_addrb),          // Data word address
        .dinb(bram_dinb),            // Data input
        .doutb(bram_doutb)           // Data output
    );
    */

    // TEMPORARY: For simulation/compilation before IP generation
    // Replace this with actual BRAM IP instantiation
    reg [31:0] temp_mem [0:2047];    // Temporary memory for testing

    initial begin
        // Initialize with NOPs for safety
        integer i;
        for (i = 0; i < 2048; i = i + 1) begin
            temp_mem[i] = 32'h00000033;
        end
        // Load from game.coe would happen in actual BRAM IP
    end

    // Temporary instruction fetch (Port A equivalent)
    assign inst_data = temp_mem[pc_addr];

    // Temporary data access (Port B equivalent)
    reg [31:0] temp_doutb;
    always @(posedge clk) begin
        if (MemRead | MemWrite) begin
            if (|bram_web)
                temp_mem[bram_addrb] <= bram_dinb;
            temp_doutb <= temp_mem[bram_addrb];
        end
    end
    assign bram_doutb = temp_doutb;

    // ========================================================================
    // Address Translation: Byte Address → Word Address
    // ========================================================================

    assign bram_addrb = addr[12:2];  // Convert byte address to word address

    // ========================================================================
    // Write Byte-Enable Generation
    // ========================================================================

    assign bram_web = MemWrite ? (
        // SW (Store Word): Write all 4 bytes
        (func3 == 3'b010) ? 4'b1111 :

        // SH (Store Halfword): Write 2 bytes based on addr[1]
        (func3 == 3'b001) ? (addr[1] ? 4'b1100 : 4'b0011) :

        // SB (Store Byte): Write 1 byte based on addr[1:0]
        (func3 == 3'b000) ? (
            (addr[1:0] == 2'b00) ? 4'b0001 :
            (addr[1:0] == 2'b01) ? 4'b0010 :
            (addr[1:0] == 2'b10) ? 4'b0100 : 4'b1000
        ) : 4'b0000
    ) : 4'b0000;

    // ========================================================================
    // Write Data Alignment
    // ========================================================================

    assign bram_dinb =
        (func3 == 3'b010) ? data_in :                                    // SW: Direct write
        (func3 == 3'b001) ? {data_in[15:0], data_in[15:0]} :           // SH: Replicate halfword
        {data_in[7:0], data_in[7:0], data_in[7:0], data_in[7:0]};      // SB: Replicate byte

    // ========================================================================
    // Read Data Extraction and Sign Extension
    // ========================================================================

    always @(*) begin
        // Default value
        data_out = 32'b0;

        // Memory-mapped I/O has priority
        if (is_mmio_pipe && MemRead_pipe) begin
            // UART data read (0x10000000)
            if (addr_pipe == 32'h10000000) begin
                data_out = {24'b0, uart_rx_data};
            end
            // UART status read (0x10000004): [1]=tx_busy, [0]=rx_valid
            else if (addr_pipe == 32'h10000004) begin
                data_out = {30'b0, uart_tx_busy, uart_rx_valid};
            end
            // LED register is write-only, return 0 on read
            else begin
                data_out = 32'b0;
            end
        end
        // Regular BRAM read
        else if (MemRead_pipe) begin
            case (func3_pipe)
                // LW (Load Word): Return full 32-bit word
                3'b010: data_out = bram_doutb;

                // LH (Load Halfword, sign-extended)
                3'b001: data_out = addr_pipe[1] ?
                    {{16{bram_doutb[31]}}, bram_doutb[31:16]} :
                    {{16{bram_doutb[15]}}, bram_doutb[15:8]};

                // LHU (Load Halfword Unsigned)
                3'b101: data_out = addr_pipe[1] ?
                    {16'b0, bram_doutb[31:16]} :
                    {16'b0, bram_doutb[15:0]};

                // LB (Load Byte, sign-extended)
                3'b000: data_out = (
                    addr_pipe[1:0] == 2'b00 ? {{24{bram_doutb[7]}}, bram_doutb[7:0]} :
                    addr_pipe[1:0] == 2'b01 ? {{24{bram_doutb[15]}}, bram_doutb[15:8]} :
                    addr_pipe[1:0] == 2'b10 ? {{24{bram_doutb[23]}}, bram_doutb[23:16]} :
                    {{24{bram_doutb[31]}}, bram_doutb[31:24]}
                );

                // LBU (Load Byte Unsigned)
                3'b100: data_out = (
                    addr_pipe[1:0] == 2'b00 ? {24'b0, bram_doutb[7:0]} :
                    addr_pipe[1:0] == 2'b01 ? {24'b0, bram_doutb[15:8]} :
                    addr_pipe[1:0] == 2'b10 ? {24'b0, bram_doutb[23:16]} :
                    {24'b0, bram_doutb[31:24]}
                );

                default: data_out = 32'b0;
            endcase
        end
    end

    // ========================================================================
    // Memory-Mapped I/O Write Logic
    // ========================================================================

    initial begin
        led_reg = 16'b0;
        uart_tx_we = 1'b0;
        uart_rx_re = 1'b0;
    end

    always @(posedge clk) begin
        // Default: De-assert pulse signals
        uart_tx_we <= 1'b0;

        if (MemWrite & ~MemRead) begin
            // LED control (0x20000000)
            if (addr == 32'h20000000) begin
                led_reg <= data_in[15:0];
            end
            // UART transmit (0x10000000)
            else if (addr == 32'h10000000) begin
                uart_tx_data <= data_in[7:0];
                uart_tx_we <= 1'b1;  // Pulse for 1 cycle
            end
        end
    end

    // UART receive read enable (combinational)
    always @(*) begin
        uart_rx_re = 1'b0;
        if (MemRead & ~MemWrite) begin
            if (addr == 32'h10000000) begin
                uart_rx_re = 1'b1;
            end
        end
    end

endmodule
