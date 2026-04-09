`timescale 1ns / 1ps

module top(
    input wire CLK,
    input wire RST,

    // Huskylens UART
    input wire RX,
    output wire TX,

    // Bluetooth
    input wire BT_RX,
    output wire BT_TX,

    // 초음파 센서
    input wire echo,
    output wire trig,

    // 부저
    output wire buzzer,

    // 기울기 센서
    input  wire tilt_sensor,  // ⬅ 추가
    output wire led,          // ⬅ 추가

    // 디버깅 UART
    output wire TX_PC,

    // 모터 제어
    output wire left_fwd,
    output wire left_bwd,
    output wire right_fwd,
    output wire right_bwd,

    // Huskylens 상태 표시
    output wire BUSY
);

    //────────────────────────────────────────────
    // 1. 내부 연결 신호 선언
    //────────────────────────────────────────────
    wire [7:0] auto_duty_lf, auto_duty_lb, auto_duty_rf, auto_duty_rb;
    wire [7:0] manual_duty_lf, manual_duty_lb, manual_duty_rf, manual_duty_rb;
    wire [7:0] recv_data;
    wire       recv_valid;
    reg        mode_auto;

    wire [15:0] distance;
    wire        valid;
    wire        stop;

    //────────────────────────────────────────────
    // 2. 서브 모듈 인스턴스 연결
    //────────────────────────────────────────────

    // Huskylens 기반 자동 주행 모듈
    color color_inst (
        .CLK(CLK), .RST(RST),
        .RX(RX), .TX(TX),
        .TX_PC(TX_PC), .BUSY(BUSY),
        .stop(stop),
        .auto_duty_lb(auto_duty_lb), .auto_duty_rb(auto_duty_rb),
        .auto_duty_lf(auto_duty_lf), .auto_duty_rf(auto_duty_rf)
    );

    // 블루투스 기반 수동 주행 제어
    motor_pwm_uart motor_pwm_uart_inst (
        .clk(CLK), .rst(RST),
        .bt_rx(BT_RX), .bt_tx(BT_TX),
        .manual_duty_lf(manual_duty_lf), .manual_duty_lb(manual_duty_lb),
        .manual_duty_rf(manual_duty_rf), .manual_duty_rb(manual_duty_rb),
        .recv_data(recv_data), .recv_valid(recv_valid)
    );

    // 초음파 센서 거리 측정
    ultrasonic ultrasonic_inst (
        .clk(CLK), .rst(RST),
        .trig(trig), .echo(echo),
        .distance(distance), .valid(valid)
    );

    // 거리 기반 부저 + stop 신호 생성
    buzzer buzzer_inst (
        .clk(CLK), .rst(RST),
        .distance(distance), .valid(valid),
        .buzzer(buzzer), .stop(stop)
    );

    // 기울기 감지 시 LED 3초 점등
    tilt_led_3s tilt_led_3s_inst (
        .clk(CLK), .rst(RST),
        .tilt_sensor(tilt_sensor),
        .led(led)
    );

    //────────────────────────────────────────────
    // 3. 주행 모드 전환: 'A' = 자동, 'M' = 수동
    //────────────────────────────────────────────
    always @(posedge CLK or posedge RST) begin
        if (RST)
            mode_auto <= 1; // 기본 자동 모드
        else if (recv_valid) begin
            if (recv_data == "M")
                mode_auto <= 0;
            else if (recv_data == "A")
                mode_auto <= 1;
        end
    end

    //────────────────────────────────────────────
    // 4. PWM 신호 선택 (모드에 따라)
    //────────────────────────────────────────────
    wire [7:0] duty_lf = mode_auto ? auto_duty_lf : manual_duty_lf;
    wire [7:0] duty_lb = mode_auto ? auto_duty_lb : manual_duty_lb;
    wire [7:0] duty_rf = mode_auto ? auto_duty_rf : manual_duty_rf;
    wire [7:0] duty_rb = mode_auto ? auto_duty_rb : manual_duty_rb;

    //────────────────────────────────────────────
    // 5. 모터 PWM 생성
    //────────────────────────────────────────────
    pwm_generator pwm_lf(.clk(CLK), .rst(RST), .duty(duty_lf), .pwm_out(left_fwd));
    pwm_generator pwm_lb(.clk(CLK), .rst(RST), .duty(duty_lb), .pwm_out(left_bwd));
    pwm_generator pwm_rf(.clk(CLK), .rst(RST), .duty(duty_rf), .pwm_out(right_fwd));
    pwm_generator pwm_rb(.clk(CLK), .rst(RST), .duty(duty_rb), .pwm_out(right_bwd));

endmodule

