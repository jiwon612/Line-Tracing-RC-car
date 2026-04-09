`timescale 1ns / 1ps
`define B9600 1250

module motor_pwm_uart (
    input  wire clk,
    input  wire rst,
    input  wire bt_rx,
    output wire bt_tx,
    output wire [7:0] manual_duty_lf,
    output wire [7:0] manual_duty_lb,
    output wire [7:0] manual_duty_rf,
    output wire [7:0] manual_duty_rb,
    output wire [7:0] recv_data,
    output wire       recv_valid
);

    wire [7:0] rx_data;
    wire rcv;
    wire ready;
    reg  start;
    reg  [7:0] tx_data;
    reg  [7:0] duty_lf, duty_lb, duty_rf, duty_rb;
    reg  mode_auto_reg;

    reg        boost_mode;
    reg [20:0] boost_counter;
    localparam BOOST_TIME = 1_200_000;

    localparam [7:0] NORMAL_LF = 8'd200;
    localparam [7:0] NORMAL_RF = 8'd203;
    localparam [7:0] BOOST_PWM = 8'd205;

    UART_RX #(.BAUDRATE(`B9600)) uart_rx (
        .clk(clk), .reset(rst), .rx(bt_rx), .rcv(rcv), .data(rx_data)
    );

    UART_TX #(.BAUDRATE(`B9600)) uart_tx (
        .clk(clk), .reset(rst), .start(start), .data(tx_data), .tx(bt_tx), .ready(ready)
    );

    wire [7:0] corrected_data = rx_data >> 1;

    assign recv_data  = corrected_data;
    assign recv_valid = rcv;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            boost_mode    <= 0;
            boost_counter <= 0;
        end else if (boost_mode) begin
            if (boost_counter >= BOOST_TIME) begin
                boost_mode    <= 0;
                boost_counter <= 0;
            end else begin
                boost_counter <= boost_counter + 1;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            start <= 0;
            tx_data <= 8'd0;
            duty_lf <= 0; duty_lb <= 0;
            duty_rf <= 0; duty_rb <= 0;
            mode_auto_reg <= 1;
        end else begin
            start <= 0;
            if (rcv && ready) begin
                tx_data <= corrected_data;
                start <= 1;

                case (corrected_data)
                    "f": begin boost_mode <= 1; duty_lf <= BOOST_PWM; duty_lb <= 0; duty_rf <= BOOST_PWM; duty_rb <= 0; end
                    "b": begin duty_lf <= 0; duty_lb <= NORMAL_LF; duty_rf <= 0; duty_rb <= NORMAL_RF; end
                    "l": begin duty_lf <= 0; duty_lb <= BOOST_PWM; duty_rf <= BOOST_PWM; duty_rb <= 0; end
                    "r": begin duty_lf <= BOOST_PWM; duty_lb <= 0; duty_rf <= 0; duty_rb <= BOOST_PWM; end
                    "s": begin duty_lf <= 0; duty_lb <= 0; duty_rf <= 0; duty_rb <= 0; end
                    default: begin duty_lf <= 0; duty_lb <= 0; duty_rf <= 0; duty_rb <= 0; end
                endcase
            end

            if (!rst && boost_mode == 0 && corrected_data == "f") begin
                duty_lf <= NORMAL_LF; duty_lb <= 0;
                duty_rf <= NORMAL_RF; duty_rb <= 0;
            end
        end
    end

    assign manual_duty_lf = duty_lf;
    assign manual_duty_lb = duty_lb;
    assign manual_duty_rf = duty_rf;
    assign manual_duty_rb = duty_rb;

endmodule
