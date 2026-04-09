`timescale 1ns / 1ps

module tilt_led_3s #(
    parameter CLK_FREQ = 12_000_000,
    parameter TILT_TIME = CLK_FREQ * 5,  // 5초 = 60M
    parameter LED_TIME  = CLK_FREQ * 3   // 3초 = 36M
)(
    input  wire clk,
    input  wire rst,
    input  wire tilt_sensor,   // 0 = 기울어짐
    output reg  led            // LED 출력
);

reg [25:0] tilt_counter;
reg [25:0] led_counter;
reg        tilt_valid;
reg        led_on;

// ─────────────────────────────
// 1. 기울기 5초 이상 감지
// ─────────────────────────────
always @(posedge clk or posedge rst) begin
    if (rst) begin
        tilt_counter <= 0;
        tilt_valid   <= 0;
    end else begin
        if (tilt_sensor == 1'b0) begin
            if (tilt_counter < TILT_TIME)
                tilt_counter <= tilt_counter + 1;
            else
                tilt_valid <= 1;
        end else begin
            tilt_counter <= 0;
            tilt_valid   <= 0;
        end
    end
end

// ─────────────────────────────
// 2. LED 3초간 켜기 (1회성)
// ─────────────────────────────
always @(posedge clk or posedge rst) begin
    if (rst) begin
        led_counter <= 0;
        led_on      <= 0;
    end else begin
        if (tilt_valid && led_counter == 0) begin
            led_on      <= 1;
            led_counter <= LED_TIME;
        end else if (led_counter > 0) begin
            led_counter <= led_counter - 1;
            if (led_counter == 1)
                led_on <= 0;  // 3초 후 OFF
        end

        // 기울기 복구 시 상태 초기화
        if (tilt_sensor == 1'b1) begin
            led_on      <= 0;
            led_counter <= 0;
        end
    end
end

// ─────────────────────────────
// 3. 출력 연결
// ─────────────────────────────
always @(*) begin
    led = led_on;
end

endmodule
