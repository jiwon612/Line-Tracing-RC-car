`timescale 1ns / 1ps

module UART_TX #(
    parameter BAUDRATE = 1250 // 12MHz / 9600bps
)(
    input  wire clk,
    input  wire reset,
    input  wire start,
    input  wire [7:0] data,
    output reg  tx,
    output reg  ready
);

    reg [3:0] bitc;
    reg [9:0] shifter;
    reg [10:0] baud_cnt;
    reg sending;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bitc    <= 0;
            shifter <= 10'b1111111111;
            tx      <= 1'b1;
            ready   <= 1'b1;
            baud_cnt <= 0;
            sending <= 0;
        end else begin
            if (start && ready) begin
                shifter <= {1'b1, data, 1'b0};  // Stop + Data + Start
                bitc    <= 0;
                sending <= 1;
                ready   <= 0;
            end else if (sending) begin
                if (baud_cnt == BAUDRATE - 1) begin
                    baud_cnt <= 0;
                    tx <= shifter[0];
                    shifter <= {1'b1, shifter[9:1]};
                    bitc <= bitc + 1;
                    if (bitc == 9) begin
                        sending <= 0;
                        ready <= 1;
                        tx <= 1'b1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end
        end
    end
endmodule
