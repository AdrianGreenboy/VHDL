/* minimal freestanding string.h: implemented in main.c */
#ifndef RV_MIN_STRING_H
#define RV_MIN_STRING_H
#include <stddef.h>
void * memset( void * d, int c, size_t n );
void * memcpy( void * d, const void * s, size_t n );
size_t strlen( const char * s );
#endif
