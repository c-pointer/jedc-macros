#if !defined(__INT_IS_WORD__)
#define __INT_IS_WORD__
typedef unsigned int uint_t __attribute__ ((__mode__ (__word__)));
typedef signed   int int_t  __attribute__ ((__mode__ (__word__)));
#endif
