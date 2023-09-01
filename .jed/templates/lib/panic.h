/*
 *	panic & logfile routines
 *
 *	define before include this file:
 *		NO_LOGFILE - write to stderr instead of logfile
 *		__PANIC_IMPL - include the implementation code
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

#if !defined(__PANIC_H) 
#define __PANIC_H

#include <stdio.h>
#include <stdarg.h>
#include <stdlib.h>
#include <errno.h>
#include <time.h>
#if defined(__linux__)
	#include <syslog.h>
#endif
#include <assert.h>
#include "c-types.h"

#if defined(__cplusplus)
extern "C" {
#endif

/*
 * the most famous function in whole universe; created at
 * 1 Jan 1970 at 0 seconds since the big bang started
 */
#ifdef SLANG_VERSION
	#define XENV_SHUTDOWN() { SLang_reset_smg(); SLang_reset_tty(); }
#else
	#define XENV_SHUTDOWN()
#endif

#if defined(__linux__)
	#define	panic(FMT, ...) \
		{ int e = errno; \
		syslog(0, FMT, ##__VA_ARGS__); \
		XENV_SHUTDOWN(); \
		fprintf(stderr, "[%16jd] %s:%d errno=%d = %s\n", time(NULL), __FILE__, __LINE__, e, strerror(e)); \
		fprintf(stderr, FMT, ##__VA_ARGS__); \
		abort(); }
#else
	#define	panic(FMT, ...) \
		{ int e = errno; \
		XENV_SHUTDOWN(); \
		fprintf(stderr, "[%16jd] %s:%d errno=%d = %s\n", time(NULL), __FILE__, __LINE__, e, strerror(e)); \
		fprintf(stderr, FMT, ##__VA_ARGS__); \
		abort(); }
#endif

/* if expression "EXP" has true value runs panic */
#define	panic_if(EXP, FMT, ...) \
	{ if ( EXP ) panic(FMT ##__VA_ARGS__); }

/* if expression "EXP" has true value runs panic */
#define	panic_ifnot(EXP, FMT, ...) \
	{ if ( EXP ) panic(FMT ##__VA_ARGS__); }

/*
 *	while the panic was a small routine in all unix program,
 *	more advanced version wanted preprocessor; so that is the
 *	upper name of panic.
 */
#define PANIC(...) panic(__VA_ARGS__)

/*
 *	standard log-file routines
 */
#if defined(NO_LOGFILE)
	#define setlogfile(s);
	#define logpf(f, ...);
#else
	void setlogfile(const char *);
	void logpf(const char *fmt, ...);
#endif

#if defined(__cplusplus)
	}
#endif

/*
 *	IMPLEMENTATION
 */
#ifdef __PANIC_IMPL
#undef __PANIC_IMPL

#include <stdbool.h>
#include <stdint.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <unistd.h>
#include <sys/stat.h>
#include "c-types.h"

#define LOG_FILE_MAX		0x10000
/* #include "panic.h" */

#if defined(__cplusplus)
extern "C" {
#endif

char __panic_logfile[PATH_MAX] = "/tmp/panic.log";

void setlogfile(const char *src)
{ strcpy(__panic_logfile, src); }

void logpf(const char *fmt, ...) {
	FILE *fp;
	va_list ap;
	struct stat st;

	va_start(ap, fmt);
	if ( stat(__panic_logfile, &st) == 0 ) {
		if ( st.st_size >= LOG_FILE_MAX ) {
			if ( (fp = fopen(__panic_logfile, "r")) != NULL ) {
				char *buf = (char *) malloc(st.st_size + 1);
				if ( buf == NULL ) PANIC("Out of memory!");
				char *p = buf;
				int_t ln = 0, remove_lines = st.st_size >> 8;

				fread(buf, st.st_size, 1, fp);
				fclose(fp);
				
				buf[st.st_size] = '\0';
				while ( (p = strrchr(p+1, '\n')) != NULL ) {
					ln ++;
					if ( ln == remove_lines )
						break;
					}
				if ( p ) *p = '\0';

				if ( (fp = fopen(__panic_logfile, "w")) != NULL ) {
					fwrite(buf, strlen(buf), 1, fp);
					fclose(fp);
					}
				free(buf);
				}
			}
		}
	if ( (fp = fopen(__panic_logfile, "a")) != NULL ) {
		vfprintf(fp, fmt, ap);
		fclose(fp);
		}
	va_end(ap);
	}

#if defined(__cplusplus)
	}
#endif

#endif

#endif /* __PANIC_H */
