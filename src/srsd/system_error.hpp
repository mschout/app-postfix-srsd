// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#ifndef DNSDB_SYSTEM_ERROR_HPP
#define DNSDB_SYSTEM_ERROR_HPP

#include <errno.h>

namespace srsd {

    class system_error : public std::system_error {
        public:
            /**
             * throw system error with an error value and reason
             * @param ev the error value
             * @param reason the reasson
             */
            system_error(int ev, const std::string& reason) :
                std::system_error(ev, std::system_category(), reason) {};

            /**
             * throw a system error with the current value of errno
             * @param reason the error message
             */
            system_error(const std::string& reason) :
                std::system_error(errno, std::system_category(), reason) {};
    };

}

#endif
