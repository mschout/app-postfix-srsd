// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#ifndef SRSD_SERVER_HPP
#define SRSD_SERVER_HPP

#include <srs2/srs2.hpp>
#include "socket_server.hpp"

class srsd_server : public socket_server {
    public:
        // delete default/copy constructors
        srsd_server() = delete;
        srsd_server(const srsd_server&) = delete;

        explicit srsd_server(const std::string& path, const std::string& domain) :
            socket_server(path), m_domain(domain) { };

        std::string domain() {
            return m_domain;
        }

        void handle_connection(int socket) override;

        void load_secrets(const std::string& path);

    private:
        void forward(int socket, const std::string& address);

        void reverse(int socket, const std::string& address);

        srs2::guarded m_srs;
        std::string m_domain;
        int peer_fd = 0;
};

#endif
