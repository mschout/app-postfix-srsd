AM_CPPFLAGS = @BOOST_CPPFLAGS@ -DPIDDIR='"$(PIDDIR)"'

AM_LDFLAGS = @BOOST_PROGRAM_OPTIONS_LDFLAGS@ @BOOST_PROGRAM_OPTIONS_LIBS@ -lsrs2xx

EXTRA_DIST = srsd \
	netstring.hpp \
	pid_file.hpp \
	slogstream.hpp \
	socket_server.hpp \
	srsd_server.hpp \
	bsd.h

sbin_PROGRAMS = postfix-srsd

postfix_srsd_SOURCES = socket_server.cpp \
	srsd_server.cpp \
	netstring.cpp \
	slogstream.cpp \
	pid_file.cpp \
	flopen.c \
	daemon.c \
	getprogname.c \
	main.cpp
