`timescale 1ns/1ps
`define BAUD_RATE 9600

module color #(
    parameter CLK_FREQ = 12_000_000
)(
    input  wire CLK,
    input  wire RST,

    // Huskylens ↔ FPGA
    input  wire RX,
    output wire TX,

    // PC 디버깅(UART)
    output wire TX_PC,
    output reg  BUSY,

    // 🚨 장애물 정지 신호
    input  wire stop,

    // 모터 PWM duty
    output wire [7:0] auto_duty_lb,
    output wire [7:0] auto_duty_rb,
    output wire [7:0] auto_duty_lf,
    output wire [7:0] auto_duty_rf
);

//────────────────────────────────────────────
// 0. 상수
//────────────────────────────────────────────
localparam integer BAUD_DIV = CLK_FREQ / `BAUD_RATE;

//────────────────────────────────────────────
// 1. 0.1 s 타이머 → Huskylens 요청
//────────────────────────────────────────────
reg [23:0] timer;  reg send_trigger;
always @(posedge CLK or posedge RST) begin
    if (RST) begin
        timer <= 0; send_trigger <= 0;
    end else if (timer == CLK_FREQ/10-1) begin
        timer <= 0; send_trigger <= 1;
    end else begin
        timer <= timer + 1; send_trigger <= 0;
    end
end

//────────────────────────────────────────────
// 2. Huskylens 명령 송신 (Soft-UART)
//────────────────────────────────────────────
reg [7:0] CMD [0:5];
initial begin CMD[0]=8'h55; CMD[1]=8'hAA; CMD[2]=8'h11; CMD[3]=8'h00; CMD[4]=8'h24; CMD[5]=8'h34; end
reg tx_busy; reg [2:0] tx_idx; reg [3:0] tx_bit; reg [15:0] tx_baud_cnt; reg [9:0] tx_shift; reg TX_REG;
assign TX = TX_REG;

always @(posedge CLK or posedge RST) begin
    if (RST) begin tx_busy<=0; BUSY<=0; TX_REG<=1; tx_idx<=0; tx_bit<=0; tx_baud_cnt<=0; end
    else if (!tx_busy && send_trigger) begin
        tx_busy<=1; BUSY<=1; tx_idx<=0; tx_bit<=0;
        tx_shift<={1'b1, CMD[0], 1'b0}; tx_baud_cnt<=0;
    end
    else if (tx_busy) begin
        if (tx_baud_cnt==BAUD_DIV-1) begin
            tx_baud_cnt<=0;
            TX_REG<=tx_shift[0]; tx_shift<={1'b1,tx_shift[9:1]};
            tx_bit<=tx_bit+1;
            if (tx_bit==9) begin
                if (tx_idx<5) begin tx_idx<=tx_idx+1; tx_bit<=0; tx_shift<={1'b1,CMD[tx_idx+1],1'b0}; end
                else begin tx_busy<=0; BUSY<=0; TX_REG<=1; end
            end
        end else tx_baud_cnt<=tx_baud_cnt+1;
    end
end

// 3. HuskyLens 데이터 수신 (소프트-UART)
reg [7:0] rx_pkt [0:15];
reg [4:0] rx_idx; reg [3:0] rx_bit; reg [15:0] rx_baud_cnt;
reg [9:0] rx_shift; reg rx_busy; reg rx_sync0, rx_sync1; reg RX_READY;
wire rx_negedge =  rx_sync1 & ~rx_sync0;
always @(posedge CLK or posedge RST) begin
    if (RST) begin rx_sync0<=1; rx_sync1<=1; rx_busy<=0; rx_baud_cnt<=0; rx_bit<=0; rx_idx<=0; RX_READY<=0; end
    else begin
        rx_sync0<=RX; rx_sync1<=rx_sync0; RX_READY<=0;
        if (!rx_busy && rx_negedge) begin rx_busy<=1; rx_bit<=0; rx_baud_cnt<=BAUD_DIV>>1; end
        else if (rx_busy) begin
            if (rx_baud_cnt==BAUD_DIV-1) begin
                rx_baud_cnt<=0; rx_shift<={rx_sync1,rx_shift[9:1]}; rx_bit<=rx_bit+1;
                if (rx_bit==9) begin rx_busy<=0; rx_pkt[rx_idx]<=rx_shift[8:1]; rx_idx<=rx_idx+1;
                    if (rx_idx==15) begin rx_idx<=0; RX_READY<=1; end
                end
            end else rx_baud_cnt<=rx_baud_cnt+1;
        end
    end
end

// 4. 방향 판단 (Δx 부호 기준)
reg signed [15:0] dx,dy;  reg [2:0] DIRECTION;
wire signed [15:0] dx_n = $signed({rx_pkt[6], rx_pkt[ 5]});
wire signed [15:0] dy_n = $signed({rx_pkt[ 8], rx_pkt[ 7]});
wire signed [15:0] height= $signed({rx_pkt[12],rx_pkt[11]});
wire signed [15:0] width= $signed({rx_pkt[10],rx_pkt[9]});
always @(posedge CLK or posedge RST) begin
    if (RST) begin dx <= 0; dy <= 0; DIRECTION <= 3'b111; end
    else if (RX_READY) begin
        dx <= dx_n; dy <= dy_n;
        if (dx_n==0 || dy_n==0) begin
            DIRECTION <= 3'b000;
        end
        // *** ② 직각 블록 구간 (dy_n > 140) ***
        if(height<140)
        DIRECTION<=(dx_n>=130&&dx_n<190)?3'b110:(dx_n<130)?3'b101:3'b110;
        else if(dx_n<130)
        DIRECTION<=3'b001;
        else if(dx_n>190)
        DIRECTION<=3'b010;
        else DIRECTION<=3'b111;
       end
end

//────────────────────────────────────────────
// 5. 모터 PWM (stop=1 ⇒ 정지)
//────────────────────────────────────────────
reg [7:0] duty_left, duty_right, dir_left, dir_right;

always @(posedge CLK or posedge RST) begin
    if (RST) begin
        duty_left<=0; duty_right<=0; dir_left<=0; dir_right<=0;
    end else if (stop) begin             // 🚨 장애물 감지 시 모터 OFF
        duty_left<=0; duty_right<=0;
        dir_left<=0; dir_right<=0;
    end else begin
        dir_left<=8'd255; dir_right<=8'd255;
        case (DIRECTION)
            3'b000:  begin duty_left<=8'd255; duty_right<=8'd200; end //no block
            3'b001:  begin duty_left<=8'd230; duty_right<=8'd160; end //left
            3'b101:  begin duty_left<=8'd255; duty_right<=8'd170; end //수직left
            3'b010:  begin duty_left<=8'd160; duty_right<=8'd230; end //right
            3'b110:  begin duty_left<=8'd170; duty_right<=8'd255; end //수직right
            3'b011:  begin duty_left<=8'd165; duty_right<=8'd165; end //slow 직진
            default: begin duty_left<=8'd200; duty_right<=8'd200; end //직진
        endcase

    end
end

assign auto_duty_lf = dir_left;
assign auto_duty_lb = duty_left;
assign auto_duty_rf = dir_right;
assign auto_duty_rb = duty_right;


endmodule
