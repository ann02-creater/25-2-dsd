# Nexys A7 짝/홀수 맞추기 게임 프로젝트 빌드 플로우  
*(DarkRISCV 기반 5‑stage RISC‑V CPU 프로젝트 가이드)*  

---

## 1. 프로젝트 개요

- **목표**  
  - Nexys A7(Artix‑7) 보드 위에 5‑stage pipeline RISC‑V 프로세서를 구현.  
  - PC(TeraTerm)에 정수를 입력하면:
    - 짝수 → `"짝수입니다!"` 출력  
    - 홀수 → `"홀수입니다!"` 출력  
  - CPU가 받은 정수를 7‑segment 8자리(최대 8자리)로 표시.  
- **입출력 조건**  
  - UART: Nexys A7 USB‑UART ↔ PC TeraTerm (예: 115200bps, 8N1).  
  - 7‑Segment: 입력 정수 표시, 나머지 자리는 `0` 또는 blank 처리.  

이 문서는 DarkRISCV 레포(`rtl/`, `src/`, `boards/`)를 베이스로, 위 프로젝트를 구현하기 위해  
어떤 소스를 어떻게 가져다 쓰고, 어떤 부분을 새로 설계해야 하는지 **빌드 플로우 관점에서 단계별**로 정리한 것입니다.

---

## 2. DarkRISCV 코드 베이스 요약

### 2.1 디렉터리 구조

- `rtl/`
  - `darkriscv.v` : RISC‑V 코어(파이프라인, 레지스터 파일, ALU, 분기 처리 등).  
  - `darkram.v`   : SoC 내부 unified BRAM 메모리 (현재는 `darksocv.mem`을 `$readmemh`).  
  - `darkio.v`    : 보드 ID, 타이머, GPIO, UART, (옵션)SPI 등 주변장치 I/O.  
  - `darkuart.v`  : UART TX/RX 모듈.  
  - `darksocv.v`  : SoC Top (코어 + BRAM + IO + SDRAM glue).  
  - `config.vh`   : 파이프라인 단계, 메모리 크기, 보드 클럭, UART 속도 등 전역 설정.  
- `src/`
  - `darklibc/`   : DarkRISCV용 C 라이브러리 (`io.c`, `stdio.c` 등).  
  - 여러 예제 앱(`darkshell`, `coremark`, `primes` 등)과 링크 스크립트 `darksocv.lds`.  
  - `Makefile`    : RISC‑V GCC로 C 코드를 빌드하여 `darksocv.mem` 등을 생성.  
- `sim/`
  - Icarus Verilog 기반 시뮬레이션(테스트벤치) 예제.  
- `boards/`
  - 보드별(Xilinx/Lattice/Altera) 프로젝트/제약 예제 (`QMTECH_ARTIX7_A35` 등).  

### 2.2 기본 메모리/IO 맵 개념

현재 DarkSoCV(`rtl/darksocv.v`)의 주소 상위 2비트를 이용한 구조:

- `XADDR[31:30] == 2'b00` → BRAM (`darkram.v`)  
- `XADDR[31:30] == 2'b01` → IO 블록 (`darkio.v`)  
- `XADDR[31:30] == 2'b10` → SDRAM 또는 unmapped  
- `XADDR[31:30] == 2'b11` → unmapped  

`darkio.v` 내부에서 하위 비트(`XADDR[4:0]`)로 다음과 같은 레지스터를 제공:

- `000xx` : 보드 ID, 코어 ID, IRQ 상태 등  
- `001xx` : UART 레지스터 (`darkuart`와 연결)  
- `010xx` : LED 레지스터  
- `011xx` : 타이머 설정  
- `100xx` : 마이크로초 카운터  
- `101xx` : 입력 포트(`IPORT`)  
- `110xx` : 출력 포트(`OPORT`) – GPIO/7‑segment 제어에 활용 가능  

이 구조를 참고해 **자신의 5‑stage CPU + 새 top(`fpga_debugger.v`)**에서도 유사한 메모리 맵을 설계하면 C 코드 이식이 쉬워집니다.

---

## 3. 전체 빌드 플로우 개요

프로젝트 전체 흐름을 크게 나누면 다음과 같습니다.

1. **툴체인/환경 준비**
2. **CPU/SoC 구조 및 재사용 범위 결정**
3. **짝/홀수 게임 C 코드 작성 및 RISC‑V 빌드**
4. **.elf → .coe 변환 및 BRAM 초기화 파일 생성**
5. **Verilog 상위 설계 (`fpga_debugger.v`) 및 I/O 매핑**
6. **데이터/명령 메모리(BRAM) 설계 (`data_mem.v` 등)**
7. **UART 모듈 설계/포팅**
8. **7‑Segment, 스위치, LED 등 주변 회로 설계**
9. **Vivado 프로젝트 생성, Nexys A7 제약(XDC) 작성, 합성/Place&Route**
10. **테스트 및 디버깅 (시뮬레이션 + 실제 보드)**  

아래에서 각 단계를 자세히 설명합니다.

---

## 4. 1단계 – 툴체인 / 환경 준비

### 4.1 RISC‑V 크로스 컴파일러

- DarkRISCV README 예시:
  - `CROSS = riscv32-embedded-elf`  
  - `CCPATH = /usr/local/share/gcc-$(CROSS)/bin/`  
- 프로젝트에서는 다음과 같은 툴 중 하나를 설치:
  - `riscv32-unknown-elf-gcc` 또는  
  - `riscv32-embedded-elf-gcc`  
- 설치 후:
  - PATH에 추가 후 `riscv32-unknown-elf-gcc --version` 으로 확인.  

### 4.2 Verilog 시뮬레이터 (선택)

- Icarus Verilog (`iverilog`) + GTKWave(파형 확인).  
- DarkRISCV의 `sim/` 구조를 참고하여:
  - CPU 단독 테스트벤치,  
  - BRAM/IO 동작 검증용 테스트벤치 작성에 활용.  

### 4.3 Vivado + Nexys A7

- Nexys A7에 맞는 Vivado 버전 설치.  
- Nexys A7 보드 파일 사용 또는 직접 Artix‑7 XC7A100T/200T 디바이스 선택.  
- 새 Vivado 프로젝트를 만들고, 나중에 작성할 RTL/constraints를 추가할 준비를 합니다.

---

## 5. 2단계 – CPU/SoC 구조 및 재사용 범위 정리

### 5.1 그대로 재사용할 부분 (개념)

질문에서 말한 “data_path.v, control_unit.v, Hazard/Forward Unit, ALU …”는  
당신이 사용할 5‑stage RISC‑V 코어의 구조입니다.  
DarkRISCV 레포에서는 `darkriscv.v` 안에 이 역할이 대부분 들어 있습니다.

**재사용 아이디어**

- 5‑stage 코어는 기존 프로젝트(혹은 다른 레포)의:
  - `data_path.v`, `control_unit.v`, Hazard/Forward Unit 등은 그대로 사용.  
  - ALU 부분은 DarkRISCV의 연산 구현(`darkriscv.v`의 RMDATA/branch 비교 로직 등)을 참고하여 기능 확장/검증.  

### 5.2 수정해서 사용할 부분

1. **메모리 인터페이스 (`data_mem.v` 역할)**  
   - Nexys A7 BRAM 특성:
     - 32‑bit(4바이트) 정렬,  
     - 동기식 read (1클럭 latency).  
   - DarkRISCV의 `darkram.v`는 unified 32‑bit 메모리를 사용하며 `$readmemh`로 초기화.  
   - 당신의 프로젝트에서는:
     - **명령 메모리**: BRAM + COE 초기화 (C 코드에서 만든 .coe 사용).  
     - **데이터 메모리**: BRAM 또는 분리된 `data_mem.v` 모듈 설계.  
     - CPU의 `DADDR`, `DATAO`, `DATAI`, byte enable, read/write handshake에 맞춰 설계.  

2. **불필요한 기능 제거 (branch predictor, compressed 등)**  
   - 이번 프로젝트 목적(간단한 게임)에는 필요없는 고급 기능은:
     - 해당 Verilog 모듈을 프로젝트에 포함하지 않거나,  
     - `ifdef`로 비활성화하여 합성 대상에서 제외.  

### 5.3 직접 구현할 부분

1. **Top 모듈 (`fpga_debugger.v`)**  
   - 역할:
     - Nexys A7 실제 핀 (clk, reset, UART, 7‑segment, 스위치, LED 등)을 내부 신호와 매핑.  
     - CPU 코어, 메모리(BRAM), UART, 7‑segment 드라이버 등을 인스턴스화.  
     - 스위치로 **동작 모드(예: 게임 모드 / 디버그 모드)** 전환 로직 구현.  

2. **UART 모듈**  
   - DarkRISCV의 `rtl/darkuart.v`를 참고/포팅:  
     - 보드 클럭(`config.vh`의 `BOARD_CK`)과 원하는 보레이트(`__UARTSPEED__`)를 맞춰 divisor 계산.  
     - CPU에서는 UART를 **메모리‑맵 레지스터**로 접근 (RX FIFO / TX FIFO / status).  

3. **짝/홀수 게임 C 코드**  
   - RISC‑V용 C로 작성한 뒤:
     - RISC‑V GCC로 컴파일 → ELF → (당신이 가진) Python 스크립트로 COE 변환.  
     - Vivado BRAM IP의 초기화 파일로 사용.  

---

## 6. 3단계 – 짝/홀수 게임 C 코드 빌드 플로우

### 6.1 C 코드 구조 (논리)

간단히 아래와 같은 흐름을 갖는 C 프로그램을 작성합니다.

1. UART 초기화 (보레이트 설정 – DarkRISCV 예제는 이미 맞춰져 있으므로 재사용 가능).  
2. 무한 루프:
   - TeraTerm에서 정수를 문자열로 입력받음 (예: `getline` 또는 직접 문자를 읽어 '\n'까지 버퍼링).  
   - 문자열 → 정수 변환 (예: `atoi` 또는 직접 구현).  
   - 정수가 8자리 초과이면: IDLE 상태로 두거나 다시 입력 요구.  
   - 짝/홀 판단: `n % 2 == 0` ?  
     - 짝수 → `"짝수입니다!\r\n"` UART로 출력.  
     - 홀수 → `"홀수입니다!\r\n"` UART로 출력.  
   - 7‑segment용 출력 레지스터에 정수 값을 기록 (메모리‑맵된 GPIO 레지스터).  

DarkRISCV 레포의 `src/darklibc/io.c`, `stdio.c`를 참고하면  
UART를 이용한 `printf`, `getchar` 등의 구현 방식을 그대로 따라 할 수 있습니다.

### 6.2 RISC‑V 빌드 플로우

1. **링크 스크립트 이해**  
   - `src/darksocv.lds`:
     - `MEM` 영역이 `ORIGIN = 0x00000000, LENGTH = MLEN` 로 정의.  
     - `MLEN` 값은 `rtl/config.vh`의 `MLEN`(비트 수)을 읽어 `2**MLEN` 바이트로 치환됩니다.  
   - 당신의 프로젝트에서도:
     - 명령/데이터 메모리 총 용량에 맞게 `LENGTH`를 맞춰야 합니다.  

2. **새 애플리케이션 디렉터리 만들기**  
   - 예: `src/oddeven/` 디렉터리 생성 후:
     - `main.c` (짝/홀수 게임),  
     - 필요시 간단한 `Makefile` 또는 기존 `darklibc` 연동.  

3. **RISC‑V 컴파일**  
   - 기본 형태:
     - `riscv32-unknown-elf-gcc -Wall -Os -march=rv32i -mabi=ilp32 -T your_linker.lds -nostartfiles -o oddeven.elf main.c ...`  
   - DarkRISCV 예제를 그대로 따라가고 싶다면:
     - `src/Makefile`를 참고하여 `APPLICATION = oddeven` 형태로 확장.  
     - `make` 실행 시 `darksocv.mem` 또는 `darksocv.rom.mem/.ram.mem`이 생성되도록 수정.  

4. **ELF → COE 변환**  
   - 이미 만들어 둔 Python 스크립트 사용:
     - `oddeven.elf` 혹은 `darksocv.mem`을 입력으로 받아  
       Vivado에서 사용할 `.coe` 파일 생성.  
   - 주의:
     - DarkRISCV의 `.mem` 포맷은 32비트 워드마다 16진수 8자리 텍스트 한 줄입니다.  
     - COE의 radix/포맷(HEX, word 단위)을 이에 맞게 변환해야 합니다.  

이 단계까지 완료되면 **게임 펌웨어가 포함된 BRAM 초기화 파일(.coe)** 를 확보한 상태가 됩니다.

---

## 7. 4단계 – Top 모듈(`fpga_debugger.v`) 및 메모리/버스 구조

### 7.1 Top 모듈 개략

`fpga_debugger.v`는 Nexys A7의 실제 핀과 내부 SoC를 연결하는 최상위 모듈입니다.  
(구체적인 포트명은 Nexys A7 XDC에 맞춰 조정.)

필수 입출력:

- 입력:
  - `CLK100MHZ` (보드 100MHz 클럭)  
  - `btnC` 또는 리셋 버튼  
  - `UART_RXD` (PC → FPGA)  
  - 스위치 (모드 선택 등)  
- 출력:
  - `UART_TXD` (FPGA → PC)  
  - 7‑segment (`seg[6:0]`, `an[7:0]`)  
  - LED (`led[15:0]` 등)  

내부 인스턴스 예시:

- 5‑stage RISC‑V CPU (당신의 `data_path.v` + `control_unit.v` + Hazard/Forward + ALU)  
- 명령/데이터 메모리 모듈 (`instr_mem.v`, `data_mem.v` 또는 BRAM IP)  
- UART 모듈 (DarkRISCV의 `darkuart.v` 참조)  
- 7‑segment 드라이버 모듈 (`sevenseg_driver.v`)  
- 간단한 GPIO/레지스터 블록 (7‑segment 값, LED 값 등을 메모리‑맵으로 제공)  

### 7.2 CPU ↔ 메모리/IO 버스 설계

DarkRISCV 코어의 인터페이스(`rtl/darkriscv.v`)는 다음과 같습니다 (개념만 요약):

- 명령 버스:
  - `IADDR[31:0]` : instruction address  
  - `IDATA[31:0]` : instruction data  
  - `IDREQ`, `IDACK` : 요청/응답 핸드셰이크  
- 데이터 버스:
  - `DADDR[31:0]` : data address  
  - `DATAO[31:0]` : write data  
  - `DATAI[31:0]` : read data  
  - `DLEN[2:0]`   : access 길이 (byte/half/word)  
  - `DBE[3:0]`    : byte enable  
  - `DRD`, `DWR`, `DDREQ`, `DDACK` : read/write 제어 및 핸드셰이크  

당신의 5‑stage CPU도 비슷한 형태의 버스를 가진다면:

1. **명령 메모리**  
   - `IADDR`의 상위 비트를 무시하고, 하위 비트(`addr[MLEN-1:2]`)로 BRAM 주소를 사용.  
   - **동기식 read**:  
     - `IADDR`를 클럭에 맞춰 BRAM 주소로 넣고,  
     - 다음 클럭에 `IDATA`를 출력.  
   - wait‑state가 필요하면 CPU에서 IDACK을 1클럭 늦춰주거나, DarkRISCV처럼 `__WAITSTATE__`로 조절.  

2. **데이터 메모리 + IO 디코더**  
   - 주소 상위 비트로 구분:
     - `0x0000_0000` ~ : 데이터 RAM  
     - `0x4000_0000` ~ : IO 영역 (UART, 7‑segment, LED, 스위치 등)  
   - 예:
     - `0x4000_0000` : DarkRISCV의 `struct DARKIO` 베이스 주소와 맞추면 C 코드 재사용이 쉬움.  
     - 내부에서 `XADDR[4:0]`를 이용해 UART/LED/OPORT 등 세부 레지스터를 구현.  
   - 7‑segment 출력:
     - 예를 들어 `OPORT` 레지스터의 상위 32비트를 “표시할 정수”로 정의,  
     - 7‑segment 드라이버 모듈이 이 값을 받아 디지털/세그먼트 패턴으로 변환.  

### 7.3 모드 전환 (스위치)

- 예:
  - `sw[0] == 0` → **게임 모드**:  
    - CPU가 7‑segment, LED, UART를 모두 제어.  
  - `sw[0] == 1` → **디버그 모드**:  
    - 7‑segment에 현재 PC 값이나 레지스터 내용을 표시하는 등의 모드.  
- `fpga_debugger.v` 안에서:
  - `sw`에 따라 7‑segment 입력 소스를 MUX로 선택하는 구조를 설계.

---

## 8. 5단계 – UART 모듈 설계 및 TeraTerm 연동

### 8.1 UART 하드웨어

- DarkRISCV의 `rtl/darkuart.v`를 참조해서:
  - 보드 클럭 주파수(`config.vh`의 `BOARD_CK`)에 맞는 divisor 계산.  
  - 8N1, 115200bps 기준 TX/RX 로직 구현.  
  - RX FIFO/ TX FIFO는 프로젝트 난이도에 따라 필수/옵션으로 선택.  

### 8.2 UART 레지스터 맵 (예시)

`darkio.v`와 유사하게:

- `0x4000_0004` : UART status (TX empty, RX available 등)  
- `0x4000_0008` : UART data (write → TX, read → RX)  

이렇게 정의하고, C 코드에서는:

- `getchar()`, `putchar()`, `printf()` 등이 이 레지스터를 읽고/쓰도록 구현하면 됩니다.  

### 8.3 TeraTerm 설정

- 보드 USB‑UART 포트 연결.  
- TeraTerm 설정:
  - Baud rate: `115200` (또는 `config.vh`의 `__UARTSPEED__`와 일치하도록 설정).  
  - Data: 8 bit, Parity: None, Stop: 1 bit.  
- TeraTerm에서 숫자를 입력하면 C 코드가 UART를 통해 값을 읽어 짝/홀 판단 및 7‑segment 갱신.

---

## 9. 6단계 – 7‑Segment, 스위치, LED 드라이버

### 9.1 7‑Segment 드라이버 설계

- 입력:
  - 32‑bit 또는 8‑digit BCD 값 (`seg_value[31:0]` 등).  
- 출력:
  - `an[7:0]` : 각 자리 enable  
  - `seg[6:0]` (+ dp) : 세그먼트 패턴  
- 동작:
  - 내부 카운터로 빠르게 자릿수를 순환(멀티플렉싱).  
  - 표시할 숫자가 8자리보다 길 경우:
    - C 코드 단계에서 입력 값을 제한하거나,  
    - 드라이버 단에서 상위 자리만 보여줌.  

### 9.2 CPU와 7‑Segment 연동

- 메모리‑맵 레지스터 예:
  - `0x4000_0020` : 7‑segment 표시 값 레지스터.  
- C 코드:
  - 사용자가 입력한 정수 `n`을 그대로 이 레지스터에 저장.  
  - 드라이버는 `n`을 10진수/16진수로 분해해 각 자리 숫자를 표시.  

---

## 10. 7단계 – Vivado 프로젝트 및 Nexys A7 제약

### 10.1 Vivado 프로젝트 생성

1. 새 RTL 프로젝트 생성.  
2. 디바이스: Nexys A7에 대응되는 Artix‑7 선택.  
3. 소스 추가:
   - 당신의 5‑stage CPU 관련 Verilog (`data_path.v`, `control_unit.v`, ALU 등).  
   - 메모리 인터페이스 (`data_mem.v`, `instr_mem.v` 또는 BRAM IP).  
   - UART 모듈, 7‑segment 드라이버.  
   - Top 모듈 `fpga_debugger.v`.  
   - 필요 시 DarkRISCV의 일부 모듈(`darkuart.v` 내용, ALU 로직 등)을 참고용/복사.  
4. BRAM IP 설정:
   - COE 초기화 파일로 **짝/홀수 게임 C 코드**가 들어간 파일을 연결.  
   - 주소 폭, 데이터 폭(32bit) 등 CPU와 일치하게 설정.  

### 10.2 XDC 제약 파일

- Nexys A7 매뉴얼을 참고하여:
  - 클럭 (`CLK100MHZ`), 리셋 버튼, 스위치, LED, 7‑segment, UART의 핀을  
    `fpga_debugger.v` 포트와 연결.  
- 예:
  - `set_property PACKAGE_PIN W5 [get_ports {CLK100MHZ}]`  
  - `set_property IOSTANDARD LVCMOS33 [get_ports {CLK100MHZ}]`  
  - (UART, 7‑segment 핀도 각각 매핑)  

### 10.3 합성/배치배선/비트스트림 생성

1. Synthesis → Implementation → Bitstream Generation 순서로 수행.  
2. Warn/Timing 에러 확인:
   - 기본적으로 게임 앱은 고속 동작이 필요 없으므로,  
     50~100MHz 정도면 충분.  

---

## 11. 8단계 – 테스트 및 디버깅

1. 보드에 비트스트림 다운로드.  
2. TeraTerm 연결 후:
   - 정수 `7` 입력 → `"홀수입니다!"` 출력, 7‑segment에 7 표시.  
   - 정수 `8` 입력 → `"짝수입니다!"` 출력, 7‑segment에 8 표시.  
3. 8자리 초과 입력 시:
   - C 코드에서 IDLE 처리 또는 에러 메시지 출력.  
4. 이상 동작 시:
   - Vivado ILA(옵션)나 시뮬레이션(iverilog)을 이용해  
     CPU ↔ 메모리 ↔ UART ↔ 7‑segment 신호를 단계별로 추적.  

---

## 12. 마무리 및 확장 아이디어

- 이 문서의 플로우는 **파이프라인 단계(3‑stage/5‑stage)** 와 무관하게 그대로 적용됩니다.  
  중요한 것은:
  - (1) CPU의 명령/데이터 버스 프로토콜,  
  - (2) 메모리/IO의 메모리‑맵,  
  - (3) C 코드와 링크 스크립트의 주소 일치입니다.  
- DarkRISCV의 RTL/펌웨어 구조를 참고하면:
  - 간단한 게임뿐 아니라, 이후에 타이머/인터럽트, SPI, SDRAM 등을 붙여  
    더 복잡한 시스템으로 확장하기도 쉽습니다.  

이제 이 빌드 플로우를 기준으로 Verilog와 C 코드를 하나씩 채워 넣으면,  
Nexys A7 위에서 동작하는 5‑stage RISC‑V 짝/홀수 게임 프로젝트를 완성할 수 있습니다.

