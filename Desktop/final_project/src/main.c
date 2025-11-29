#include <stdint.h>

#define UART_DATA   (*(volatile uint32_t *)0x10000000)
#define UART_STATUS (*(volatile uint32_t *)0x10000004)
#define LED_ADDR    (*(volatile uint32_t *)0x20000000)

void putc(char c) {
    // TX Busy가 꺼질 때까지 대기
    while (UART_STATUS & 0x2); 
    UART_DATA = c;
}

void print(const char *str) {
    while (*str) putc(*str++);
}

char getc() {
    // RX Valid가 켜질 때까지 대기
    while (!(UART_STATUS & 0x1));
    return (char)(UART_DATA & 0xFF);
}

int main() {
    char c;
    print("\n\r=== Even/Odd Game Start! ===\n\r");
    print("Type a number (0-9): \n\r");

    while (1) {
        c = getc(); // 키보드 입력 대기
        putc(c);    // 에코 (내가 친 거 화면에 보여주기)

        if (c >= '0' && c <= '9') {
            int num = c - '0';
            if (num % 2 == 0) {
                print(" -> Even!\n\r");
                LED_ADDR = 0xFFFF; // 짝수: LED 켜짐
            } else {
                print(" -> Odd!\n\r");
                LED_ADDR = 0x0000; // 홀수: LED 꺼짐
            }
        } else {
            print(" -> Not a number.\n\r");
        }
    }
    return 0;
}