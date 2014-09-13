// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#ifndef SOCK_SERVER_HPP
#define SOCK_SERVER_HPP

#include <mutex>
#include <string>

class socket_server {
    public:
        socket_server(const std::string& path, int num_workers=2)
            : m_path(path), m_num_workers(num_workers) { }

        ~socket_server();

        void bind();

        void run();

        void stop() { m_stop = true; }

        void drop_privileges(const std::string& user, const std::string& group);

        virtual void handle_connection(int socket) = 0;

    protected:
        void on_accept(int socket);

        std::mutex m_mutex;
        std::string m_path;
        int m_num_workers;
        int m_socket = -1;
        bool m_stop = false;
};

#endif
