/* Minimal C runtime helpers for bare-metal FreeRTOS build (no libc) */

#include <stddef.h>

void *memset( void *s, int c, size_t n )
{
    unsigned char *p = (unsigned char *)s;
    while( n-- ) *p++ = (unsigned char)c;
    return s;
}

void *memcpy( void *dst, const void *src, size_t n )
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s2 = (const unsigned char *)src;
    while( n-- ) *d++ = *s2++;
    return dst;
}

/* GCC built-in helper: count leading zeros (used by portGET_HIGHEST_PRIORITY) */
int __clzsi2( unsigned int x )
{
    int n = 32;
    if( x == 0 ) return 32;
    if( x & 0xFFFF0000 ) { n -= 16; x >>= 16; }
    if( x & 0x0000FF00 ) { n -=  8; x >>=  8; }
    if( x & 0x000000F0 ) { n -=  4; x >>=  4; }
    if( x & 0x0000000C ) { n -=  2; x >>=  2; }
    if( x & 0x00000002 ) { n -=  1; }
    return n - 1;
}
