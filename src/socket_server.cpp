// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include <iostream>
#include <set>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <pwd.h>
#include <grp.h>
#include <fcntl.h>
#include <signal.h>
#include "srsd/system_error.hpp"

#include "socket_server.hpp"

using std::string;
std::set<pid_t> children;

static void sigchld_handler(int s)
{
    pid_t pid;

    // reap exited child process(es).
    while ((pid = waitpid(-1, NULL, WNOHANG)) > 0)
        children.erase(pid);
}

static void headhunter(int s)
{
    // ask all child processes to exit
    for (const auto& pid : children)
        kill(pid, SIGINT);

    exit(0);
}

static void install_sigchld_handler()
{
    struct sigaction sa;
    sa.sa_handler = sigchld_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    if (sigaction(SIGCHLD, &sa, NULL) == -1)
        throw srsd::system_error("sigaction");
}

static void install_sigint_handler()
{
    struct sigaction sa;
    sa.sa_handler = headhunter;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;

    if (sigaction(SIGINT|SIGTERM, &sa, NULL) == -1)
        throw srsd::system_error("sigaction");
}

void socket_server::bind() {
    struct sockaddr_un addr;
    int is_on = 1;

    m_stop = false;

    if ((m_socket = socket(AF_UNIX, SOCK_STREAM, 0)) < 0)
        throw srsd::system_error("Could not create the socket");

    if (setsockopt(m_socket, SOL_SOCKET, SO_REUSEADDR, &is_on, sizeof(is_on)) != 0)
        throw srsd::system_error("Could not set reuse-address socket option");

    unlink(m_path.c_str());

    bzero(&addr, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, m_path.c_str(), m_path.length());

    auto old_umask = umask(S_IXUSR | S_IXGRP | S_IXOTH);

    if (::bind(m_socket, (struct sockaddr*) &addr, sizeof(addr)) != 0)
        throw srsd::system_error("Cound not bind");

    if (listen(m_socket, SOMAXCONN) != 0)
        throw srsd::system_error("Could not listen");

    umask(old_umask);
}

socket_server::~socket_server()
{
    if (m_socket > 0)
        close(m_socket);
}

void socket_server::run() {
    install_sigchld_handler();
    install_sigint_handler();

    struct sockaddr peer_addr;
    socklen_t peer_addr_len;
    peer_addr_len = sizeof(peer_addr);

    while (!m_stop) {
        int peer = accept(m_socket, &peer_addr, &peer_addr_len);

        if (peer < 0) {
            std::clog << "accept failed: " << strerror(errno) << std::endl;
            continue;
        }

        pid_t pid = fork();

        switch (pid) {
            case -1:
                throw srsd::system_error("fork");
                break;

            case 0:
                // child
                close(m_socket);

                try {
                    handle_connection(peer);
                }
                catch (std::exception& e) {
                    std::clog << "exception: " << e.what() << std::endl;
                }

                exit(0);

            default:
                children.insert(pid);
                close(peer);
        }
    }
}

void socket_server::drop_privileges(const string& user, const string& group)
{
    // can't drop privileges if we are not running as root
    if (getuid() != 0)
        return;

    uid_t uid = 0;
    gid_t gid = 0;

    // look up gid
    if (!group.empty()) {
        struct group *gr;

        if ((gr = getgrnam(group.c_str())) == NULL)
            throw srsd::system_error("getgrnam");

        gid = gr->gr_gid;

        endpwent();
    }

    // look up uid
    if (!user.empty()) {
        struct passwd *pw;

        if ((pw = getpwnam(user.c_str())) == NULL)
            throw srsd::system_error("getpwnam");

        uid = pw->pw_uid;

        endpwent();
    }

    // chown the socket
    if (uid != 0 || gid != 0)
        if (chown(m_path.c_str(), uid, gid) < 0 && errno != ENOENT)
            throw srsd::system_error("chown");

    // drop group privs
    if (gid != 0)
        if (setgid(gid) < 0)
            throw srsd::system_error("setgid");

    // drop user privs
    if (uid != 0)
        if (setuid(uid) < 0)
            throw srsd::system_error("setuid");
}
