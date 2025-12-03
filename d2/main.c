#include <stdint.h>

#define UART_DATA   (*(volatile uint32_t *)0x10000000) //tx write, rx_read주소 
#define UART_STATUS (*(volatile uint32_t *)0x10000004)// uart 상태 register 주소
#define LED_ADDR    (*(volatile uint32_t *)0x20000000)
//data_out = {30'b0, uart_tx_busy, uart_rx_valid};로 되어있음
void putc(char c) {
    while (UART_STATUS & 0x2); //tx_busy는  bit1이므로 2와 AND연산
    UART_DATA = c;
}

void print(const char *str) {
    while (*str) putc(*str++);
}

char getc() {
    while (!(UART_STATUS & 0x1)); //rx_valid는 bit0이므로 1과 AND연산
    return (char)(UART_DATA & 0xFF);
}

int main() {
    char c;
    print("\n\r=== Even/Odd Game Start! ===\r\n");
    print("Type a number (0-9): \r\n");

    while (1) {
        c = getc(); // 키보드 입력 대기
        putc(c);    // 에코 (내가 친 거 화면에 보여주기)

        if (c >= '0' && c <= '9') {
            int num = c - '0';
            if (num % 2 == 0) {
                print(" -> Even!\r\n");
                LED_ADDR = 0xFFFF; // 짝수: LED 켜짐
            } else {
                print(" -> Odd!\r\n");
                LED_ADDR = 0x0000; // 홀수: LED 꺼짐
            }
        } else {
            print(" -> Not a number.\r\n");
            
        }
    }
    return 0;
}