`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/22 05:52:43
// Design Name: 
// Module Name: ultrasonic
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

module ultrasonic (
    input wire clk,             // 12MHz clock
    input wire rst,             // Active high reset
    output reg trig,            // Trigger to HC-SR04
    input wire echo,            // Echo from HC-SR04
    output reg [15:0] distance, // Measured distance in cm
    output reg valid            // High when new distance is available
);

    localparam CLK_FREQ = 12000000;
    localparam TRIG_PERIOD = CLK_FREQ / 10;  // 100ms
    localparam TRIG_PULSE = 1200;            // 10us pulse

    reg [31:0] trig_cnt = 0;
    reg echo_d, echo_start;
    reg [31:0] echo_timer = 0;

    always @(posedge clk) begin
        if (rst) begin
            trig_cnt <= 0;
            trig <= 0;
        end else begin
            trig_cnt <= trig_cnt + 1;
            if (trig_cnt < TRIG_PULSE)
                trig <= 1;
            else
                trig <= 0;
            if (trig_cnt >= TRIG_PERIOD)
                trig_cnt <= 0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            echo_d <= 0;
            echo_start <= 0;
            echo_timer <= 0;
            distance <= 0;
            valid <= 0;
        end else begin
            echo_d <= echo;
            echo_start <= echo & ~echo_d;  // Rising edge detect

            if (echo_start)
                echo_timer <= 0;
            else if (echo)
                echo_timer <= echo_timer + 1;
            else if (~echo & echo_d) begin // Falling edge
                distance <= echo_timer / 696; // Distance in cm
                valid <= 1;
            end else
                valid <= 0;
        end
    end
endmodule



