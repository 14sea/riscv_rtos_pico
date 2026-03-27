/* Bare-metal test firmware for PicoRV32 SoC */

#include <stdint.h>

/* Memory-mapped I/O registers */
#define UART_TXDATA (*(volatile uint32_t *)0x80000000)
#define UART_RXDATA (*(volatile uint32_t *)0x80000004)
#define UART_STATUS (*(volatile uint32_t *)0x80000008)

/* UART status bits */
#define UART_TX_READY 0x01
#define UART_RX_VALID 0x02

static void uart_putc(char c)
{
    while (!(UART_STATUS & UART_TX_READY))
        ;
    UART_TXDATA = (uint32_t)c;
}

static void uart_puts(const char *s)
{
    while (*s)
        uart_putc(*s++);
}

static void uart_put_hex(uint32_t val)
{
    static const char hex[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4)
        uart_putc(hex[(val >> i) & 0xF]);
}

static void delay(volatile int count)
{
    while (count-- > 0)
        ;
}

/* Default IRQ handler (called from assembly if IRQ support is added later) */
void irq_handler(void)
{
}

void main(void)
{
    uart_puts("\r\n");
    uart_puts("==============================\r\n");
    uart_puts("  PicoRV32 SoC on AX301\r\n");
    uart_puts("  RV32IM @ 50 MHz\r\n");
    uart_puts("==============================\r\n");

    /* Test SRAM read/write */
    volatile uint32_t *sram = (volatile uint32_t *)0x20000000;
    sram[0] = 0xDEADBEEF;
    sram[1] = 0xCAFEBABE;

    uart_puts("SRAM test: ");
    if (sram[0] == 0xDEADBEEF && sram[1] == 0xCAFEBABE) {
        uart_puts("PASS\r\n");
    } else {
        uart_puts("FAIL ");
        uart_put_hex(sram[0]);
        uart_puts(" ");
        uart_put_hex(sram[1]);
        uart_puts("\r\n");
    }

    /* Test MUL instruction (RV32M) */
    uart_puts("MUL test:  ");
    volatile int a = 12345;
    volatile int b = 6789;
    volatile int c = a * b;
    if (c == 83810205) {
        uart_puts("PASS\r\n");
    } else {
        uart_puts("FAIL ");
        uart_put_hex((uint32_t)c);
        uart_puts("\r\n");
    }

    uart_puts("\r\nReady. Echo mode:\r\n");

    /* Echo loop: receive and echo back */
    while (1) {
        if (UART_STATUS & UART_RX_VALID) {
            char ch = (char)(UART_RXDATA & 0xFF);
            uart_putc(ch);
            if (ch == '\r')
                uart_putc('\n');
        }
    }
}
