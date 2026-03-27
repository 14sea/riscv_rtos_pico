/* Bare-metal syscalls for ThreadX — syscalls.c
 * Provides memset, memcpy, __clzsi2 used by ThreadX kernel.
 */

#include <stddef.h>

void *memset(void *dst, int c, size_t n)
{
    unsigned char *p = (unsigned char *)dst;
    while (n--) *p++ = (unsigned char)c;
    return dst;
}

void *memcpy(void *dst, const void *src, size_t n)
{
    unsigned char       *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

/* Count-leading-zeros for 32-bit integers (used by ThreadX priority bitmap) */
int __clzsi2(unsigned int x)
{
    int n = 0;
    if (x == 0) return 32;
    if (!(x & 0xFFFF0000)) { n += 16; x <<= 16; }
    if (!(x & 0xFF000000)) { n +=  8; x <<=  8; }
    if (!(x & 0xF0000000)) { n +=  4; x <<=  4; }
    if (!(x & 0xC0000000)) { n +=  2; x <<=  2; }
    if (!(x & 0x80000000)) { n +=  1; }
    return n;
}
