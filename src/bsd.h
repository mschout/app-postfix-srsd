#ifndef _BSD_H
#define _BSD_H

#include "config.h"

#include <stdlib.h>
#include <sys/fcntl.h>

#ifdef HAVE_LIBUTIL_H
#include <libutil.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef HAVE_FLOPEN
int flopen(const char *_path, int _flags, ...);
#endif

#ifndef HAVE_DAEMON
int daemon(int nochdir, int noclose);
#endif

#ifndef HAVE_GETPROGNAME
const char *getprogname();
#endif

#ifdef __cplusplus
}
#endif

#endif
