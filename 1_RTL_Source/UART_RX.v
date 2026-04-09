`timescale 1ns / 1ps

module UART_RX #(
    parameter BAUDRATE = 1250  // 12MHz / 9600bps
)(
    input  wire clk,
    input  wire reset,
    input  wire rx,
    output reg  rcv,
    output reg [7:0] data
);
    reg [3:0] bitc;
    reg [9:0] shifter;
    reg [10:0] baud_cnt;
    reg busy;
    reg [2:0] rx_sync = 3'b111;

    always @(posedge clk)
        rx_sync <= {rx_sync[1:0], rx};

    wire start_edge = (rx_sync[2:1] == 2'b10);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            bitc <= 0; shifter <= 0; baud_cnt <= 0;
            busy <= 0; data <= 0; rcv <= 0;
        end else begin
            rcv <= 0;
            if (!busy && start_edge) begin
                busy <= 1;
                baud_cnt <= BAUDRATE >> 1;
                bitc <= 0;
            end else if (busy) begin
                if (baud_cnt == BAUDRATE - 1) begin
                    baud_cnt <= 0;
                    shifter <= {rx_sync[1], shifter[9:1]};
                    bitc <= bitc + 1;
                    if (bitc == 9) begin
                        busy <= 0;
                        data <= shifter[8:1];
                        rcv <= 1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 1;
                end
            end
        end
    end
endmodule
