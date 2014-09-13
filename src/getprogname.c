// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include "config.h"

#ifndef HAVE_GETPROGNAME
#define _GNU_SOURCE

#include <stdlib.h>
#include <errno.h>

const char * getprogname()
{
    return program_invocation_short_name;
}

#endif /* !HAVE_GETPROGNAME */
