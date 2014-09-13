// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include <iostream>
#include <unistd.h>
#include "netstring.hpp"
#include "srsd/system_error.hpp"

using std::runtime_error;
using std::string;

static void write_string (int socket, const string& value)
{
    int bytes_written = 0;
    int len = value.length();

    while (len > 0) {
        if ((bytes_written = write(socket, value.data(), len)) < 0)
            throw srsd::system_error("write");

        if (bytes_written == 0)
            throw runtime_error("EOF during write");

        len -= bytes_written;
    }
}

static int read_bytes(int socket, char *buf, size_t len)
{
    int bytes_read = 0;

    while (len > 0) {
        if ((bytes_read = read(socket, buf, len)) < 0)
            throw srsd::system_error("read");

        if (bytes_read == 0)
            return 0;

        len -= bytes_read;
    }

    return 1;
}

static size_t read_length(int socket)
{
    size_t len = 0;
    char ch;

    // read the length
    while (true) {
        if (read_bytes(socket, &ch, 1) == 0)
            return 0;

        if (ch == ':')
            break;

        int i = ch - '0';

        if (i < 0 || i > 9)
            throw runtime_error(string("read_length char out of range [0,9]:") + ch);

        if (len == 0 && i == 0)
            throw runtime_error("nestring length must not have leading zeros");

        len = 10 * len + i;
    }

    return len;
}

string netstring_read(int socket)
{
    size_t len = read_length(socket);

    if (len == 0)
        return "";

    char buffer[len];

    read_bytes(socket, buffer, len);

    string data(buffer, len);

    // read trailing comma and discard
    char ch;

    read_bytes(socket, &ch, 1);

    if (ch != ',')
        throw runtime_error("encountered malformed netstring");

    return data;
}

void netstring_write(int socket, const string& value)
{
    auto len = value.length();

    string ns = std::to_string(len) + ":" + value + ",";

    write_string(socket, ns);
}
