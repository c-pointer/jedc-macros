/*
 *	C/C++ standard data types.
 * 
 *	[u]int_t integer types to be CPU's word.
 *	[u]long_t to be CPU's double-word [if system can support it].
 *	real_t to be FPU's/CPU's word.
 *	bigr_t to be FPU's longest floating point size [if system can support it].
 *
 *	Note: for OpenGL use old float, Graphics cards still are much more faster by using.
 * 
 *	Copyright (C) 2020 Nicholas Christopoulos.
 * 
 *	This is free software: you can redistribute it and/or modify it under
 *	the terms of the GNU General Public License as published by the
 *	Free Software Foundation, either version 3 of the License, or (at your
 *	option) any later version.
 *
 *	It is distributed in the hope that it will be useful, but WITHOUT ANY
 *	WARRANTY; without even the implied warranty of MERCHANTABILITY or
 *	FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 *	for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with it. If not, see <http://www.gnu.org/licenses/>.
 *
 * 	Written by Nicholas Christopoulos <nereus@freemail.gr>
 */

#if !defined(__INT_IS_WORD_EXT__)
#define __INT_IS_WORD_EXT__

/*
 *	CPU x86_64 "Integer" Models:
 * 
 *		Type          _ILP64  _LP64  _LLP64
 *		-----------------------------------
 *		char              8      8       8
 *		short            16     16      16
 *		int              64     32      32
 *		long             64     64      32
 *		long long        64     64      64
 *		pointer          64     64      64
 */

#include <stdint.h>
#include <limits.h>

#if defined(__cplusplus)
extern "C" {
#endif

/*
 *	integer size = register size = CPU word size
 *	This is true on any case by hardware definition!
 * 
 *  Also, register size it must be equal to pointer size,
 *	at least in most cases.
 */

/* long == big int */
#if defined(__GNUC__) && (__WORDSIZE == 64)
	typedef __int128			long_t;
	typedef unsigned __int128	ulong_t;
#else
	typedef intmax_t		long_t;
	typedef uintmax_t		ulong_t;
#endif

/* int == word, real = word, big real = double word */
#if defined(_LP64) || defined(_LLP64)
	typedef intptr_t		int_t;
	typedef uintptr_t		uint_t;
	typedef double			real_t;
	typedef long double		bigr_t;

	#define __WORDSIZE64		1
	#define	INTFMT			"%jd"
	#define	UINTFMT			"%ju"
#else
	#if defined(_ILP64)
		#define __WORDSIZE64	1
	#endif
	typedef int			int_t;
	typedef unsigned	uint_t;
	typedef double		real_t;	/* 32/64 x86 */
	typedef long double	bigr_t;	/* 32/64 x86 */

	#define	INTFMT			"%d"
	#define	UINTFMT			"%u"
#endif

/* print information */
#define __INT_IS_WORD_PRINT() {\
	printf("sizeof(int)=%d, sizeof(long)=%d, sizeof(long long)=%d, sizeof(void*)=%d\n",\
		sizeof(int), sizeof(long), sizeof(long long), sizeof(void*));\
	printf("sizeof(int_t)=%d, sizeof(long_t)=%d, sizeof(real_t)=%d, sizeof(bigr_t)=%d\n",\
		sizeof(int_t), sizeof(long_t), sizeof(real_t), sizeof(bigr_t));\
	}
	
#if defined(__cplusplus)
	}
#endif

#endif
