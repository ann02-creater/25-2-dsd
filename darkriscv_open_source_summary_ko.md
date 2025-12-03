# DarkRISCV 오픈소스 코드 요약 (Nexys A7 관점)

이 문서는 DarkRISCV 레포지토리 구조와 SoC 설계 개념을, Nexys A7 위에서 간단한 짝/홀수 게임 프로젝트를 만드는 관점에서 정리한 것입니다.  
특히 질문에서 `**`로 표시된 부분들을 중심으로 설명합니다.

---

## 1. 디렉터리 구조와 주요 RTL 모듈

### 1.1 `rtl/` 디렉터리

- `darkriscv.v`  
  - RV32I 기반 RISC‑V 코어입니다.  
  - 파이프라인(`__3STAGE__` 등), ALU, 분기 처리, 레지스터 파일, 명령/데이터 버스 인터페이스를 포함합니다.

- `darkram.v`  
  - SoC 내부의 통합 BRAM 메모리입니다.  
  - `$readmemh("darksocv.mem", ...)`으로 초기값을 읽어 와서, FPGA 내부 Block RAM에 프로그램/데이터를 올리는 역할을 합니다.

- `darkio.v` – **IO 블록 (왜 필요한가?)**  
  - CPU의 데이터 버스(XADDR, XWR, XRD, XATAI/O 등)를 받아서, 보드 주변장치들을 메모리‑맵 IO 형태로 묶어주는 모듈입니다.
  - 내부에 포함되는 기능:
    - 보드 ID, 코어 ID, IRQ 플래그 등 상태 레지스터
    - 타이머, 마이크로초 카운터
    - LED, IPORT(입력), OPORT(출력) 레지스터
    - UART(`darkuart`)와 SPI(`darkspi`)에 대한 주소 디코딩 + 데이터 경유
  - 역할 정리:
    - RISC‑V 코어는 “주소 + 데이터 버스”만 알고 있을 뿐, 어떤 주소가 LED인지 UART인지 모릅니다.
    - `darkio`가 주소를 해석해서 “이 주소는 UART 레지스터”, “이 주소는 LED 레지스터”라고 나누고, 실제 하드웨어 핀에 연결합니다.
    - 따라서 CPU와 여러 주변장치 사이를 이어주는 일종의 **IO 브리지 + 디코더**라고 보면 됩니다.

- `darkuart.v` – UART TX/RX 모듈  
  - 순수 UART 송수신 모듈입니다.
  - `darkio` 안에 인스턴스되어, `XADDR`가 UART 영역(001xx)일 때만 `RD/WR` 신호를 받아 TX/RX FIFO를 동작시킵니다.
  - `darkio` = IO 전체 블록(타이머/LED/UART 등)  
    `darkuart` = 그 중 UART 엔진만 따로 분리한 모듈

- `darksocv.v` – SoC Top + **SDRAM glue**  
  - SoC 상위 모듈로, 다음을 한 군데에 모읍니다.
    - `darkriscv` 코어
    - `darkbridge` (코어 내부 버스 ↔ SoC 버스 변환)
    - `darkram` (내부 BRAM)
    - `darkio` (UART, LED, 타이머, GPIO, SPI 등)
    - 선택적인 SDRAM 컨트롤러(`mt48lc16m16a2_ctrl`, `__SDRAM__` 정의 시)
    - PLL/리셋, 디버그 핀 등
  - `XADDR[31:30]` 상위 2비트로 큰 영역을 나누고, 각 영역에 다른 모듈을 연결합니다.
  - **“SDRAM glue” 의 의미**  
    - 코어/SoC 버스는 단순한 32bit 동기식 메모리 인터페이스지만, 실제 SDRAM 칩은 초기화/리프레시/뱅크/로우 주소/타이밍 등 복잡한 프로토콜을 요구합니다.
    - 이 간극을 메워주는 SDRAM 컨트롤러 + 어댑터 로직을 통칭해서 **glue logic**이라고 부릅니다.
    - `darksocv`에서는 `XADDR[31:30]==2'b10` 영역을 SDRAM 컨트롤러(`mt48lc16m16a2_ctrl`)로 연결해 주는 부분이 곧 SDRAM glue입니다.

- `config.vh` – **파이프라인, 메모리 크기, 보드 클럭, UART 속도 등 전역 설정**  
  - 크게 세 종류의 설정이 섞여 있습니다.
  - (1) **CPU 마이크로아키텍처 선택**
    - 예: `__3STAGE__`, `__RV32E__`, `__HARVARD__`, `__CSR__`, `__INTERRUPT__` 등  
    - 모두 DarkRISCV 설계자가 성능/자원/기능을 고려해 선택한 설계 파라미터입니다.
  - (2) **메모리 크기**
    - `MLEN` (예: `MLEN 13` → 2^13 워드 = 약 32KB)  
    - 이 값은 **링커 스크립트(`src/darksocv.lds`)와 반드시 일치**해야 하며, 필요한 펌웨어가 들어갈 만큼의 크기로 설계자가 정해 둔 값입니다.
  - (3) **보드별 클럭/리셋/BOARD_ID**
    - `QMTECH_ARTIX7_A35`, `AVNET_MICROBOARD_LX9` 등 보드 매크로에 따라 `BOARD_ID`, `BOARD_CK_REF`, `BOARD_CK_MUL/DIV`, 리셋 극성(`INVRES`) 등이 설정됩니다.
    - 이 값들은 보드 매뉴얼/데이터시트(기본 클럭 주파수, 리셋 버튼 극성 등)를 참고해서 설계자가 정리한 것입니다.
  - 정리하면:
    - 순수 RISC‑V ISA 스펙이 정한 것이 아니라,  
    - **DarkRISCV 설계자가 “RISC‑V를 만족하면서, 각 FPGA 보드에서 잘 도는 조합”을 선택해 놓은 설계 파라미터 집합**입니다.

---

## 2. `src/` 구조, C 라이브러리, `.mem` 파일

### 2.1 `src/` 디렉터리 개요

- `darklibc/`  
  - DarkRISCV용 간단한 C 런타임/라이브러리입니다.
  - 주요 파일:
    - `include/io.h`, `io.c` : 메모리‑맵 IO 구조체(`struct DARKIO`)와 전역 포인터 `io`
    - `stdio.c`, `string.c` : 기본적인 `printf`, 문자열 함수 등
    - `util.S`, `boot.S` : RISC‑V 초기화/부트 코드

- 예제 앱 디렉터리 (`darkshell`, `coremark`, `primes`, `spidemo` 등)
  - DarkRISCV + SoC 구조를 테스트/벤치마크하기 위한 샘플 C 프로그램들입니다.

- `darksocv.lds`  
  - 링커 스크립트로, 코드(.text), 데이터(.data), 스택, IO 영역 등의 주소 배치를 정의합니다.
  - `config.vh`에서 정의한 메모리 크기(특히 `MLEN`)와 맞아야 합니다.

### 2.2 내 프로젝트에서 무엇을 재사용/제거할 수 있는가?

- **예제 앱들 (darkshell, coremark, primes 등)**  
  - Nexys A7 위에서 “짝/홀수 게임”과 같은 별도 앱을 만들 예정이라면,  
  - 이 예제 앱들은 **삭제하거나 무시해도 됩니다.** (빌드 대상에서 제외)

- **`darklibc`는?**  
  - 완전히 새 C 런타임/스타트업 코드를 만들 자신이 있다면, `darklibc`도 삭제 가능하지만,  
  - 보통은 C에서 `io->led`, `io->uart.fifo` 같은 메모리‑맵 접근을 편하게 하기 위해 **`darklibc/include/io.h`, `io.c` 등은 그대로 가져다 쓰는 것이 훨씬 편합니다.**
  - 최소:
    - `struct DARKIO` 정의
    - `volatile struct DARKIO *io = (void *)0x40000000;`
  - 이 두 가지만 있어도 C 코드에서 IO 레지스터를 구조체로 다룰 수 있습니다.

### 2.3 `.mem` 파일은 왜 필요한가? Vivado BRAM IP와의 관계

- 빌드 흐름 (`src/Makefile` 기준):
  1. C/어셈 코드 → `riscv-gcc`로 컴파일/링크 → `darksocv.elf` (실행 파일)
  2. `objcopy`/스크립트로 `.elf`를 헥사/바이너리 배열로 변환 → `darksocv.mem`
  3. RTL 쪽 `darkram.v`에서 `$readmemh("darksocv.mem", ...)`으로 이 파일을 읽어 BRAM 초기값으로 사용

- Vivado BRAM IP + `.coe`와 비교:
  - Vivado 방식:
    - Block Memory Generator IP를 생성하고, `.coe` 파일로 초기 컨텐츠를 지정
    - 합성/bitstream 생성 시 이 값이 BRAM에 들어감
  - DarkRISCV 방식:
    - 순수 Verilog로 `darkram.v` 작성
    - `initial` 블록에서 `$readmemh`로 `.mem` 파일을 읽어서 BRAM 초기 컨텐츠를 지정  
    - 합성 시 해당 로직이 Block RAM으로 추론되고, `.mem`이 그 초기값이 됨

- 결론:
  - `.mem`은 **“별도의 독립 메모리”가 아니라, FPGA 내부 BRAM의 초기 내용만 담고 있는 파일**입니다.
  - Nexys A7에서 Vivado BRAM IP를 직접 쓸 거라면:
    - DarkRISCV의 `.mem` 대신 `.coe`를 만들도록 툴체인을 바꾸면 됩니다.  
    - 컨셉은 동일: **소프트웨어 바이너리 → BRAM 초기값** 변환 단계입니다.

---

## 3. 기본 메모리/IO 맵 개념

### 3.1 상위 2비트(`XADDR[31:30]`) – 큰 영역 분할

- `darksocv.v`에서 SoC 전체 주소 공간을 상위 2비트로 4개 영역으로 나눕니다.

```text
XADDR[31:30] == 2'b00 → 내부 BRAM (darkram.v)
XADDR[31:30] == 2'b01 → IO 블록 (darkio.v)
XADDR[31:30] == 2'b10 → SDRAM (또는 unmapped)
XADDR[31:30] == 2'b11 → unmapped (0xdeadbeef 반환)
```

- 의미:
  - 이 값들은 **CPU가 보는 실제 물리 주소의 상위 비트**입니다.
  - 예:
    - `0x0000_1234` → 상위 2비트 `00` → 내부 BRAM 영역
    - `0x4000_0008` → 상위 2비트 `01` → IO 블록 영역
  - C 코드, 링커 스크립트, Verilog에서 모두 이 맵을 기준으로 주소를 맞춰야 합니다.

### 3.2 IO 블록 베이스 주소와 `XADDR[4:0]`

- IO 블록 베이스 주소:

```c
// src/darklibc/io.c
volatile struct DARKIO *io = (volatile struct DARKIO *)0x40000000;
```

- 즉:
  - IO 영역은 `0x4000_0000`부터 시작 (`XADDR[31:30] == 2'b01`).
  - 그 안에서 `XADDR[4:0]` (하위 5비트)로 세부 레지스터를 나눕니다 (`rtl/darkio.v`).

#### 3.2.1 Verilog 주소 디코딩 (`darkio.v`)

```verilog
casex (XADDR[4:0])
  5'b000xx: IOMUXFF <= { BOARD_IRQ, CORE_ID, BOARD_CM, BOARD_ID }; // 보드/코어/IRQ
  5'b001xx: IOMUXFF <= UDATA;   // UART 레지스터
  5'b010xx: IOMUXFF <= LEDFF;   // LED 레지스터
  5'b011xx: IOMUXFF <= TIMERFF; // 타이머 설정
  5'b100xx: IOMUXFF <= TIMEUS;  // 마이크로초 카운터
  5'b101xx: IOMUXFF <= IPORT;   // 입력 포트
  5'b110xx: IOMUXFF <= OPORTFF; // 출력 포트
  5'b111xx: IOMUXFF <= SDATA;   // SPI (옵션)
endcase
```

- 각 영역 설명:
  - `000xx` : 보드 ID, 코어 ID, IRQ 상태 등
  - `001xx` : UART 레지스터 (darkuart와 연결)
  - `010xx` : LED 레지스터
  - `011xx` : 타이머 설정
  - `100xx` : 마이크로초 카운터
  - `101xx` : 입력 포트(IPORT)
  - `110xx` : 출력 포트(OPORT)

#### 3.2.2 C 구조체와의 대응 (`struct DARKIO`)

- `src/darklibc/include/io.h`:

```c
struct DARKIO {
    unsigned char board_id; // 00
    unsigned char board_cm; // 01
    unsigned char core_id;  // 02
    unsigned char irq;      // 03

    struct DARKUART {
        unsigned char  stat; // 04
        unsigned char  fifo; // 05
        unsigned short baud; // 06/07
    } uart;

    unsigned int led;        // 08
    unsigned int timer;      // 0c
    unsigned int timeus;     // 10
    unsigned int iport;      // 14
    unsigned int oport;      // 18

    struct DARKSPI {
        union {
            unsigned char  spi8;   // 1c
            unsigned short spi16;  // 1c/1d
            unsigned int   spi32;  // 1c~1f
        };
    } spi;
};
```

- 요점:
  - C 구조체 필드의 오프셋(주석에 표시된 바이트 주소)이 Verilog의 `XADDR[4:0]` 디코딩과 정확히 대응되도록 설계되어 있습니다.
  - C에서는 그냥 `io->led`, `io->uart.fifo`처럼 구조체를 쓰면 되고,  
    내부적으로는 해당 주소가 IO 블록으로 가서 LED, UART, GPIO 핀에 연결됩니다.

### 3.3 실제 사용 예 (C 코드 관점)

```c
// LED 제어
io->led = 0x1;        // 0x40000008에 write → darkio가 LED 레지스터로 인식

// 스위치(입력 포트) 읽기
unsigned sw = io->iport;  // 0x40000014 read → 보드 스위치 상태

// UART로 문자 송신 (예시)
while (!(io->uart.stat & 1)) ;  // 송신 가능 플래그 기다리기
io->uart.fifo = 'A';            // 0x40000005 write → UART TX FIFO로 데이터 전송
```

- 정리:
  - **레지스터 주소 = C 구조체의 필드 주소**입니다.
  - Verilog는 `XADDR[31:30]` + `XADDR[4:0]`으로 이 주소를 해석하고,  
    C 코드는 `struct DARKIO`로 같은 주소를 추상화해서 사용할 뿐입니다.

---

## 4. Nexys A7에 적용할 때 참고할 보드 설정

- 레포에는 Nexys A7 전용 디렉터리는 없지만, 같은 Artix‑7 계열인  
  `boards/qmtech_artix7_a35` 예제가 가장 비슷합니다.

### 4.1 참고할 파일들

- `boards/qmtech_artix7_a35/darksocv.xdc`  
  - 클럭 입력, 리셋 버튼, UART RX/TX, LED, 스위치 등의 핀 매핑이 들어 있습니다.
  - Nexys A7 보드 매뉴얼의 핀 이름/좌표에 맞게 이 파일 내용을 수정하면 됩니다.

- `rtl/config.vh`의 `QMTECH_ARTIX7_A35` 블록  
  - Nexys A7용으로 새로운 매크로(예: `NEXYS_A7`)를 만들고,  
  - `BOARD_CK_REF`(일반적으로 Nexys A7 클럭 100MHz), `BOARD_CK_MUL/DIV`, `INVRES` 등을 Nexys A7 사양에 맞게 조정합니다.

- 상위 모듈 (`fpga_debugger.v` 또는 보드용 top)  
  - `darksocv`를 인스턴스하고 Nexys A7의 실제 보드 핀(XCLK, UART, LED, 스위치, 7‑segment 등)을 연결합니다.
  - 이때 SoC 내부 버스 구조(`XADDR`, `XWR`, `XRD`, IO 맵 등)는 그대로 유지해야, 기존 C 코드(`io->...`)를 그대로 재사용할 수 있습니다.

---

## 5. 전체 빌드 플로우 vs 파이프라인 단계

문서에서 정리한 빌드 플로우(1~10단계)는 파이프라인이 3‑stage/5‑stage인지와는 상관없이 그대로 적용됩니다.  
중요한 것은 다음 세 가지입니다.

1. **CPU의 명령/데이터 버스 프로토콜**
   - 코어 ↔ SoC 간 인터페이스 (`darkbridge`, `darkram`, `darkio`, SDRAM 컨트롤러 등)
2. **메모리/IO 메모리‑맵**
   - `XADDR[31:30]`으로 BRAM/IO/SDRAM/unmapped 분할
   - IO 블록 내부에서 `XADDR[4:0]`으로 보드 ID, UART, LED, 타이머, GPIO 등 분할
3. **C 코드와 링크 스크립트의 주소 일치**
   - 코드/데이터/스택 시작 주소를 SoC 메모리 맵과 맞춤 (`darksocv.lds`)
   - IO 베이스 주소(`0x40000000`)와 `struct DARKIO`의 필드 오프셋을 Verilog와 맞춤

Nexys A7에서 5‑stage RISC‑V 짝/홀수 게임 프로젝트를 만들 때는:

- 위 세 가지를 DarkRISCV 구조에 맞춰 그대로 유지하고,
- 상위 Verilog(`fpga_debugger.v`)에서:
  - `darksocv`의 포트를 보드 핀에 매핑,
  - BRAM 초기화 파일(.mem/.coe)을 C 빌드 결과(.elf)에서 생성하는 플로우만 잘 이어주면 됩니다.

이렇게 하면 간단한 게임뿐 아니라, 이후에 타이머/인터럽트, SPI, SDRAM 등을 붙여 더 복잡한 시스템으로 확장하기도 쉬워집니다.

