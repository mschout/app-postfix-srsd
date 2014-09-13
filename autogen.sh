#!/bin/sh

# autoreconf doesn't work properly on RHEL5.  needs newer autoconf. *sigh*
# autoreconf --force --install -I m4

libtoolize
aclocal -I m4
autoheader
automake --force --add-missing
autoconf
