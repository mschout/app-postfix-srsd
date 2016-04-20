AC_PREREQ(2.52)
AC_INIT([postfix-srsd], 0.11)
AC_CONFIG_MACRO_DIR([m4])
AM_INIT_AUTOMAKE
AC_PROG_CXX
AC_PROG_CC
AC_PROG_LIBTOOL
AC_LANG_PUSH([C++])
AX_CXX_COMPILE_STDCXX_11([noext],[mandatory])
AC_SEARCH_LIBS(daemon, [c bsd], [AC_CHECK_FUNCS(daemon)])
AC_SEARCH_LIBS(getprogname, [c bsd], [AC_CHECK_FUNCS(getprogname)])
AC_SEARCH_LIBS(flopen, [util bsd], [AC_CHECK_FUNCS(flopen)])

AC_CHECK_HEADERS(libutil.h)
AX_REQUIRE_HEADER(srs2/srs2.hpp)
dnl main is a special case here for C++ libs
dnl see https://lists.gnu.org/archive/html/autoconf/2002-03/msg00203.html
AX_REQUIRE_LIB(srs2xx, main)

AX_PIDDIR

BOOST_REQUIRE
BOOST_STRING_ALGO
BOOST_PROGRAM_OPTIONS

AC_CONFIG_HEADER(src/config.h)
AC_CONFIG_FILES([Makefile
                 src/Makefile])


AC_OUTPUT
