/* PicoRV32 FreeRTOS demo — main_freertos.c
 *
 * Three tasks:
 *   vTask1 (priority 2): prints "T1: tick N" every 500 ms
 *   vTask2 (priority 1): prints "T2: tick N" every 1000 ms
 *   Idle task (built-in, priority 0): runs when no other task is ready
 *
 * UART memory map (uart_periph.v):
 *   0x80000000  W: TX data byte   R: RX data byte
 *   0x80000004  R: RX data byte (alias)
 *   0x80000008  R: status (bit0=TX ready, bit1=RX valid)
 */

#include "FreeRTOS.h"
#include "task.h"

/* ---- UART helpers ---- */
#define UART_BASE   0x80000000UL
#define UART_TX     ( *(volatile unsigned int *)( UART_BASE + 0x0 ) )
#define UART_RX     ( *(volatile unsigned int *)( UART_BASE + 0x4 ) )
#define UART_STATUS ( *(volatile unsigned int *)( UART_BASE + 0x8 ) )
#define UART_TX_RDY ( UART_STATUS & 1 )
#define UART_RX_RDY ( UART_STATUS & 2 )

static void uart_putchar( char c )
{
    while( !UART_TX_RDY );
    UART_TX = (unsigned int)c;
}

static void uart_puts( const char *s )
{
    while( *s ) uart_putchar( *s++ );
}

/* Minimal unsigned int → decimal string (no libc) */
static void uart_putuint( unsigned int n )
{
    char buf[ 12 ];
    int  i = 0;
    if( n == 0 ) { uart_putchar( '0' ); return; }
    while( n ) { buf[ i++ ] = '0' + ( n % 10 ); n /= 10; }
    while( i-- ) uart_putchar( buf[ i ] );
}

/* ---- Tasks ---- */
static void vTask1( void *pvParameters )
{
    unsigned int tick = 0;
    ( void ) pvParameters;
    for( ;; )
    {
        uart_puts( "T1: tick " );
        uart_putuint( tick++ );
        uart_puts( "\r\n" );
        vTaskDelay( pdMS_TO_TICKS( 500 ) );
    }
}

static void vTask2( void *pvParameters )
{
    unsigned int tick = 0;
    ( void ) pvParameters;
    for( ;; )
    {
        uart_puts( "T2: tick " );
        uart_putuint( tick++ );
        uart_puts( "\r\n" );
        vTaskDelay( pdMS_TO_TICKS( 1000 ) );
    }
}

/* ---- main ---- */
int main( void )
{
    uart_puts( "\r\n== PicoRV32 FreeRTOS demo ==\r\n" );
    uart_puts( "Creating tasks...\r\n" );

    xTaskCreate( vTask1, "T1", configMINIMAL_STACK_SIZE, NULL, 2, NULL );
    xTaskCreate( vTask2, "T2", configMINIMAL_STACK_SIZE, NULL, 1, NULL );

    uart_puts( "Starting scheduler\r\n" );
    vTaskStartScheduler();

    /* Should never reach here */
    uart_puts( "Scheduler returned!\r\n" );
    for( ;; );
    return 0;
}
