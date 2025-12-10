`timescale 1ns / 1ps
module uart (
    input clk,
    input resetn,
    output ser_tx,
    input  ser_rx,
    input  [15:0] cfg_divider, 
    input  [7:0]  reg_dat_di,
    output [7:0]  reg_dat_do,
    input         reg_dat_we,
    input         reg_dat_re,
    output        tx_busy,
    output        rx_valid
);
    reg [31:0] cfg_div;
    reg [9:0] tx_shift_reg;
    reg [3:0] tx_bit_cnt;
    reg [30:0] tx_cnt;
    reg [9:0] rx_shift_reg;
    reg [3:0] rx_bit_cnt;
    reg [30:0] rx_cnt;
    reg [7:0] rx_data_reg;
    reg rx_valid_reg;

    assign reg_dat_do = rx_data_reg;
    assign ser_tx = tx_shift_reg[0];
    assign tx_busy = (tx_bit_cnt != 0);
    assign rx_valid = rx_valid_reg;
  

    always @(posedge clk) begin
        if (!resetn) begin
            tx_shift_reg <= 10'h3FF; // Idle state is high
            tx_bit_cnt <= 0;
            tx_cnt <= 0;
            rx_shift_reg <= 0;
            rx_bit_cnt <= 0;
            rx_cnt <= 0;
            rx_valid_reg <= 0;
            rx_data_reg <= 0;
        end else begin
            // Configuration 
            cfg_div <= {16'd0, cfg_divider}; 

            // Transmitter
            if (tx_cnt) tx_cnt <= tx_cnt - 1;
            else if (tx_bit_cnt) begin
                tx_shift_reg <= {1'b1, tx_shift_reg[9:1]};
                tx_bit_cnt <= tx_bit_cnt - 1;
                tx_cnt <= cfg_div;
            end else if (reg_dat_we) begin
                tx_shift_reg <= {1'b1, reg_dat_di, 1'b0}; // Stop(1) + Data + Start(0)
                tx_bit_cnt <= 10;
                tx_cnt <= cfg_div;
            end

            // Receiver
            if (reg_dat_re) rx_valid_reg <= 0; // Read Acknowledge

            if (rx_cnt) rx_cnt <= rx_cnt - 1;
            else if (rx_bit_cnt) begin
                rx_cnt <= cfg_div;
                rx_bit_cnt <= rx_bit_cnt - 1;
                rx_shift_reg <= {ser_rx, rx_shift_reg[9:1]};
                if (rx_bit_cnt == 1) begin
                    rx_data_reg <= rx_shift_reg[9:2];
                    rx_valid_reg <= 1;
                end
            end else if (!ser_rx) begin // Start bit detection
                rx_cnt <= cfg_div / 2;
                rx_bit_cnt <= 10;
            end
        end
    end
endmodule