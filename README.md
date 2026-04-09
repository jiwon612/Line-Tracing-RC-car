# 🚗 Line-Tracing RC Car

> **디지털집적회로모델링실험 Proj 2**  
> Team 6 | 2025.04 - 2025.05

---

## 📌 Project Overview

FPGA 기반 자율주행 RC카 프로젝트입니다.  
Cmod S7 FPGA 보드와 HuskyLens 카메라를 연동하여 블랙 테이프 경로를 따라 자율주행하며, 블루투스 통신 및 GUI를 통한 수동 제어도 지원합니다.

<p align="center">
  <img src="https://github.com/user-attachments/assets/7d2c1c7f-6416-4b1a-8f4c-a3957565654a" width="45%" />
  &nbsp;&nbsp;
  <img src="https://github.com/user-attachments/assets/a8cfd008-d9b0-4b8d-b808-4becc56bd238" width="45%" />
</p>

---

## 🏗️ System Architecture

```
Li-Battery (5V USB)
    └── CMOD S7 (Spartan-7 FPGA)
            ├── HuskyLens  ←→  UART 9600 Baud (PMOD 3.3V)
            │     └── Line Tracing / Color Detection
            ├── Bluetooth Module  ←→  UART (PC GUI)
            ├── PWM (2-bit)  →  Motor Driver  →  2 Motors
            └── Boost Conv. (5V VU pin)  →  9V  →  Motor Driver
```

### Top-Level I/O (`top_v1_0`)

| Port | Direction | Description |
|------|-----------|-------------|
| `CLK`, `RST` | Input | 시스템 클럭 및 리셋 |
| `RX`, `BT_RX` | Input | HuskyLens / Bluetooth UART 수신 |
| `echo` | Input | 초음파 센서 수신 |
| `tilt_sensor` | Input | 기울기 센서 |
| `TX`, `BT_TX` | Output | HuskyLens / Bluetooth UART 송신 |
| `TX_PC` | Output | PC 디버깅용 UART |
| `left_fwd/bwd`, `right_fwd/bwd` | Output | 모터 PWM 제어 |
| `trig` | Output | 초음파 센서 트리거 |
| `buzzer`, `led` | Output | 경고 부저 및 LED |
| `BUSY` | Output | UART 송신 상태 |

---

## 📦 Repository Structure

```
Line-Tracing-RC-car/
├── 1_RTL_Source/          # Verilog HDL 소스 파일
│   ├── top.v              # 최상위 모듈
│   ├── color.v            # HuskyLens 색상 기반 라인트레이싱
│   ├── motor_pwm_uart.v   # 블루투스 수동 제어 + PWM 출력
│   ├── pwm_generator.v    # PWM 신호 생성기
│   ├── ultrasonic.v       # 초음파 거리 센서
│   ├── buzzer.v           # 근접 경고 부저
│   └── tilt_led_3s.v      # 기울기 감지 LED 경고
├── 2_XDC_Constraint/      # Cmod S7 핀 제약 파일
├── 3_etc/
│   └── Laptop_Program/    # PC GUI (HTML/JS 기반)
└── 4_Presentation/        # 발표 자료
```

---

## ⚙️ Key Modules

### `color_v1_0` — HuskyLens 자율주행
- HuskyLens로부터 UART(9600 Baud)로 색상 정보 수신
- Color area difference 분석을 통한 라인 트레이싱
- `auto_duty_lb/rb/lf/rf[7:0]` 출력으로 좌우 모터 듀티 독립 제어

### `motor_pwm_uart_v1_0` — 블루투스 수동 제어
- Bluetooth UART로 PC/앱에서 수신한 명령을 PWM 듀티로 변환
- `manual_duty_lf/lb/rf/rb[7:0]` 출력

### `pwm_generator_v1_0` — PWM 생성기
- 8-bit `duty[7:0]` 입력 → `pwm_out` 출력
- 모터 속도 및 방향 제어

### `ultrasonic_v1_0` — 초음파 거리 측정
- HC-SR04 기반 trig/echo 방식
- 16-bit `distance[15:0]` 및 `valid` 출력

### `buzzer_v1_0` — 근접 경고음
- 거리에 반비례하여 부저 반복 주기 조절
- 가까울수록 빠르게 경고음 출력
- `stop` 신호로 차량 긴급 정지 연동

### `tilt_led_3s_v1_0` — 기울기 경고 LED
- 기울기 센서가 5초 이상 기울어짐 감지 시 LED 3초간 점등
- 기울기 복구 시 자동 소등 및 시스템 초기화

---

## 🖥️ GUI

PC 제어용 웹 기반 GUI (`3_etc/Laptop_Program/`)

- **비밀번호 인증**을 통한 접속 보안
- **블루투스 포트 연결/해제** 제어
- **수동/자동 주행 모드 전환** 버튼
- 현재 주행 모드 상태 표시

---

## 🔌 Hardware Setup

| 부품 | 사양 |
|------|------|
| FPGA 보드 | Digilent Cmod S7-25 (Spartan-7, xc7s25csga225) |
| 카메라 | HuskyLens (UART, 3.3V, 9600 Baud) |
| 무선 통신 | Bluetooth Module (UART) |
| 모터 드라이버 | L298N 계열 (9V 구동) |
| 거리 센서 | HC-SR04 초음파 센서 |
| 기울기 센서 | 디지털 기울기 스위치 |
| 전원 | Li-Ion 보조배터리 (5V USB) + Boost Converter (→9V) |

---

## 🛠️ Development Environment

- **Vivado 2024.1** (ML Standard Edition)
- 합성 플로우: Linter → Synthesis → Implementation → Bitstream
- 보드 프로그래밍: Temporal(RAM) / ROM(Flash) 방식 지원
- UART 모니터링: [HTerm](https://www.der-hammer.info/pages/terminal.html) (HEX 모드)

---

## 📡 UART Protocol (HuskyLens)

9600 Baud, 8N1 포맷 사용

```
Frame: [0x55][0xAA][Address][DataLen][Command][Data...][Checksum]
```

- **KNOCK command** (연결 확인): `55 AA 11 00 2C 3C`
- **RETURN OK** 응답: `55 AA 11 00 2E 3E`
- Checksum: 프레임 전체 바이트 합산의 하위 1바이트

---

## 🏁 Features Summary

| 기능 | 설명 |
|------|------|
| ✅ 자율 라인트레이싱 | HuskyLens Color 모드 기반 |
| ✅ 블루투스 수동 제어 | PC GUI 연동 |
| ✅ 초음파 근접 경고 | 거리 비례 부저 출력 |
| ✅ 기울기 감지 경고 | 5초 감지 → LED 3초 점등 |
| ✅ GUI | 웹 기반 비밀번호 인증 + 모드 전환 |

---

## 📄 References

- [Digilent Cmod S7 Reference](https://digilent.com/reference/programmable-logic/cmod-s7/start)
- [Vivado Getting Started](https://digilent.com/reference/programmable-logic/guides/getting-started-with-vivado)
- [HuskyLens UART Protocol](https://github.com/HuskyLens/HUSKYLENSArduino/blob/master/HUSKYLENS%20Protocol.md)
