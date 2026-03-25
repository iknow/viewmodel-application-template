/* ---------------------------------------------------------------------------
** This software is in the public domain, furnished "as is", without technical
** support, and with no warranty, express or implied, as to its usefulness for
** any purpose.
** -------------------------------------------------------------------------*/

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stddef.h>
#include <stdio.h>

void *dlopen(const char* filename, int flags) {
	fprintf(stderr, "Attempted to dlopen(%s, %d)\n", filename, flags);
	return NULL;
}
