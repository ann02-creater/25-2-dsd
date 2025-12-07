// ========================================
// UART LOOPBACK TEST - CPU 우회
// 수신한 데이터를 바로 다시 전송 (에코)
// 이것으로 UART HW가 정상인지 확인
// ========================================
module fpga_debugger(
    input clk,
    input rstn,
    input sw_pc,
    input uart_rx,
    output uart_tx,
    output [6:0] seg,
    output [3:0] anode,
    output [1:0] led
);

wire rst = ~rstn;

// UART signals
wire [7:0] uart_rx_data;
wire uart_rx_valid;
wire uart_tx_busy;

// Simple state machine for loopback
reg [1:0] state;
reg [7:0] tx_data;
reg tx_start;
reg rx_ack;

localparam IDLE = 2'd0;
localparam SEND = 2'd1;
localparam WAIT = 2'd2;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        tx_data <= 8'h00;
        tx_start <= 1'b0;
        rx_ack <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                tx_start <= 1'b0;
                rx_ack <= 1'b0;
                if (uart_rx_valid) begin
                    // 수신 데이터 저장
                    tx_data <= uart_rx_data;
                    rx_ack <= 1'b1;  // rx_valid 클리어
                    state <= SEND;
                end
            end
            SEND: begin
                rx_ack <= 1'b0;
                if (!uart_tx_busy) begin
                    tx_start <= 1'b1;  // 전송 시작
                    state <= WAIT;
                end
            end
            WAIT: begin
                tx_start <= 1'b0;
                if (!uart_tx_busy) begin
                    state <= IDLE;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

// UART 인스턴스
uart u_uart (
    .clk(clk),
    .resetn(!rst),
    .ser_tx(uart_tx),
    .ser_rx(uart_rx),
    .cfg_divider(16'd868),  // 100MHz / 868 = 115200 baud
    .reg_dat_di(tx_data),
    .reg_dat_do(uart_rx_data),
    .reg_dat_we(tx_start),
    .reg_dat_re(rx_ack),
    .tx_busy(uart_tx_busy),
    .rx_valid(uart_rx_valid)
);

// LED 디버그
assign led[0] = uart_rx_valid;
assign led[1] = uart_tx_busy;

// 7-segment: 수신 데이터 표시
Four_Digit_Seven_Segment_Driver_2 segger (
    .clk(clk),
    .num({8'h00, uart_rx_data}),
    .Anode(anode),
    .LED_out(seg)
);

endmodule
