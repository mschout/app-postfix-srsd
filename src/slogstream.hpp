// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#ifndef SLOGSTREAM_HPP
#define SLOGSTREAM_HPP

#include <string>
#include <iostream>
#include <syslog.h>

/** Syslog ostream class.
 *
 * This class implements an ostream style interface to syslog.
 *
 * example:
 *   slogstream log("foo", LOG_LOCAL0, LOG_INFO);
 *   log << "this is a syslog message" << endl;
 */
class slogstream: public std::ostream {
public:
    slogstream(const std::string& ident, int facility = 0, int priority = 0);

    // tie an ostream to syslog
    static slogstream* open(std::ostream& os, const int facility);
};

/** Syslog streambuf class
 *
 * This class subclasses std::streambuf to implement an ostream style 
 * interface to syslog.
 */
class slogbuf: public std::streambuf {
public:
    /**
     * create a new slogbuf()
     *
     * @param ident the syslog ident string
     * @param facility the syslog facility to use
     * @param priority the syslog priority
     */
    slogbuf(const std::string& ident, int facility = 0, int priority = 0);
    ~slogbuf();

protected:
    int overflow(int);
    int sync();

private:
    void put_buffer();
    int _priority;
    std::string m_ident;
};

#endif
