`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/22 05:50:49
// Design Name: 
// Module Name: buzzer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module buzzer(
    input wire clk,                // 12MHz clock
    input wire rst,                // Active high reset
    input wire [15:0] distance,    // Distance in cm
    input wire valid,              // Valid distance update
    output reg buzzer,             // PWM output to buzzer
    output wire stop               // 🚨 장애물 정지 신호
);
    reg [31:0] tone_cnt = 0;
    reg [31:0] tone_period = 15000; // 800Hz → 12MHz / 800Hz = 15000

    reg [31:0] beep_cnt = 0;
    reg [31:0] beep_period = 0;
    reg tone_en = 0;
    reg stop_reg;

    assign stop = stop_reg;  // 장애물 감지 시 외부로 전달

    always @(posedge clk) begin
        if (rst)
            beep_period <= 0;
        else if (valid) begin
            if (distance < 10) begin
                beep_period <= 100000;
                stop_reg <= 1;
            end
            else if (distance < 15) begin
                beep_period <= 300000;
                stop_reg <= 1;
            end
            else if (distance < 20) begin
                beep_period <= 600000;
                stop_reg <= 1;
            end
            else if (distance < 25) begin
                beep_period <= 1200000;
                stop_reg <= 1;
            end
            else if (distance < 30) begin
                beep_period <= 2400000;
            end
            else begin
                beep_period <= 32'hFFFFFFFF; // disable
                stop_reg <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            beep_cnt <= 0;
            tone_en <= 0;
        end else if (beep_period == 32'hFFFFFFFF) begin
            tone_en <= 0;
            beep_cnt <= 0;
        end else begin
            beep_cnt <= beep_cnt + 1;
            if (beep_cnt >= beep_period) begin
                beep_cnt <= 0;
                tone_en <= ~tone_en;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            tone_cnt <= 0;
            buzzer <= 0;
        end else if (!tone_en) begin
            tone_cnt <= 0;
            buzzer <= 0;
        end else begin
            tone_cnt <= tone_cnt + 1;
            if (tone_cnt < tone_period / 2)
                buzzer <= 1;
            else if (tone_cnt < tone_period)
                buzzer <= 0;
            else
                tone_cnt <= 0;
        end
    end
endmodule
