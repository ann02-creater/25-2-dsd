/* main.c - 홀짝 게임 */
#include <stdint.h>

#define NUM_INPUT (*(volatile uint32_t *)0x50000000)
#define NUM_VALID (*(volatile uint32_t *)0x50000004)
#define VGA_RESULT (*(volatile uint32_t *)0x40000000)
#define LED_ADDR (*(volatile uint32_t *)0x20000000)

int main() {
  uint32_t num;

  while (1) {
    // 숫자 입력 대기
    while (!(NUM_VALID & 0x1))
      ;

    num = NUM_INPUT;

    // 홀짝 판별
    if (num % 2 == 0) {
      VGA_RESULT = 2; // EVEN
      LED_ADDR = 0x0000;
    } else {
      VGA_RESULT = 1; // ODD
      LED_ADDR = 0xFFFF;
    }
  }
  return 0;
}