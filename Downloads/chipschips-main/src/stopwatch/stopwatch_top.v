module stop_watch_top(
    input wire clk, reset, btn,                      
    output reg [6:0] SEG,
    output reg [7:0] AN
);
    
    wire toggle;
    wire en;
    reg [2:0] sel;
    wire tc_100Hz, tc_1MHz;

    assign en = toggle;

    
    clock_divider U_CLKDIV( clk, reset, en, tc_1ms, tc_refresh );

always @(posedge clk or posedge reset) begin
if(reset) begin 
sel <=3'd0;
end else if(tc_100Hz) begin
sel <= sel+1;
end 
end     
   
    wire [3:0] Q0, Q1, Q2, Q3, Q4, Q5, Q6, Q7;
    wire tc0, tc1, tc2, tc3, tc4, tc5, tc6, tc7;


    reg [3:0] data;
    wire [6:0] sseg;

    debounce U_DEBOUNCE (clk, reset, btn, toggle);

    counter_bcd U0 (clk, reset, tc_100Hz, Q0, tc0);
    counter_bcd U1 (clk, reset, tc0, Q1, tc1);
    counter_bcd U2 (clk, reset, tc1, Q2, tc2);
    counter_mod6 U3 (clk, reset, tc2, Q3, tc3);
    counter_bcd U4 (clk, reset, tc3, Q4, tc4);
    counter_mod6 U5 (clk, reset, tc4, Q5, tc5);
    counter_bcd U6 (clk, reset, tc5, Q6, tc6);
    counter_bcd U7 (clk, reset, tc6, Q7, tc7);


    ss_decoder U_SEG (
        .bin(data),
        .seg(sseg)
    );


    always @(*) begin
        case(sel)
            3'd0: data = Q0;
            3'd1: data = Q1;
            3'd2: data = Q2;
            3'd3: data = Q3;  
            3'd4: data = Q4;
            3'd5: data = Q5;  
            3'd6: data = Q6;
            3'd7: data = Q7;
            default: data = 4'd0;
        endcase
    end

    always @(*) begin
        case(sel)
            3'd0: AN = 8'b11111110;  
            3'd1: AN = 8'b11111101;
            3'd2: AN = 8'b11111011;  
            3'd3: AN = 8'b11110111; 
            3'd4: AN = 8'b11101111;  
            3'd5: AN = 8'b11011111; 
            3'd6: AN = 8'b10111111;  
            3'd7: AN = 8'b01111111;  
            default: AN = 8'b11111111; 
        endcase
    end

    always @(*) begin
        SEG = sseg;
    end

endmodule
