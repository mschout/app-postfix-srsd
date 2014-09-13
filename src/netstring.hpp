// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#ifndef NETSTRING_HPP
#define NETSTRING_HPP

#include <string>

std::string netstring_read(int socket);

void netstring_write(int socket, const std::string& value);

#endif
