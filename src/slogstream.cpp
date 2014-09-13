// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include <stdio.h>
#include <string>
#include <syslog.h>
#include <stdarg.h>
#include "slogstream.hpp"
#include "bsd.h"

using namespace std;

ostream log(clog.rdbuf());

// creates a syslog ostream
// e.g.: slogstream slog("ident", LOG_LOCAL0, LOG_INFO);
// slog << "your message here << std::endl;
slogstream::slogstream(const string& ident, int facility, int priority):
    ostream(new slogbuf(ident, facility, priority))
{
}

// reopen the given ostream to the filename file.
// returns pointer to the newly created ostream.
slogstream *
slogstream::open(ostream& os, const int facility)
{
    // we never delete the logstream object because it must stay
    // in scope for the life of the process.
    slogstream *slog =
        new slogstream(getprogname(), facility, LOG_INFO);

    os.rdbuf(slog->rdbuf());

    os << "syslog initialized" << endl;

    return slog;
}

slogbuf::slogbuf(const string& ident, int facility, int priority):
    _priority(priority), m_ident(ident)
{
    openlog(m_ident.c_str(), 0, facility);

    // allocate a buffer and setup the buffer pointers from streambuf
    char *ptr = new char[1024];
    setp(ptr, ptr + 1024); // initialize "put" area ptrs
    setg(0, 0, 0);         // initialize "get" area ptrs
}

// make sure output was sent to the log and deallocate the buffer.
slogbuf::~slogbuf()
{
    sync();
    delete[] pbase();
}

// when the put area is full, or when std::endl, or ends is put into the
// buffer, then overflow() is called.
// "c" is the character that did not fit, or EOF if there is no character
int
slogbuf::overflow(int c)
{
    put_buffer();

    if (c != EOF)
        sputc(c);

    return 0;
}


// just flushes the buffer.
int
slogbuf::sync()
{
    put_buffer();

    return 0;
}

// writes the buffer out to syslog()
void
slogbuf::put_buffer()
{
    if (pbase() != pptr())
    {
        int len = (pptr() - pbase());

        string msg(pbase(), len);
        syslog(_priority, "%s", msg.c_str());

        setp(pbase(), epptr());
    }
}

