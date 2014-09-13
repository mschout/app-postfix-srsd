// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include <unistd.h>
#include <iostream>
#include <fstream>
#include <thread>
#include <boost/algorithm/string.hpp>
#include "srsd/system_error.hpp"
#include "srsd_server.hpp"
#include "netstring.hpp"

using std::string;

static void send_reply(int socket, const string& reply);

void srsd_server::load_secrets(const string& path)
{
    std::ifstream fin(path);

    string line;

    while (std::getline(fin, line)) {
        boost::algorithm::trim(line);

        if (!line.empty() && line[0] != '#')
            m_srs.add_secret(line);
    }
}

void srsd_server::handle_connection(int socket)
{
    peer_fd = socket;

    while (true) {
        // type<space>email
        string query;
        query = netstring_read(socket);

        if (query.empty())
            break;

        std::vector<std::string> request;
        boost::algorithm::split(request, query, boost::is_any_of(" "));

        if (request[0] == "srsencoder") {
            forward(socket, request[1]);
        }
        else if (request[0] == "srsdecoder") {
            reverse(socket, request[1]);
        }
        else {
            std::clog << "unknown command type: " << request[0] << std::endl;
            // XXX throw?
            break;
        }
    }
}

void srsd_server::forward(int socket, const string& address)
{
    try {
        if (address.find_first_of("@") == string::npos)
            return send_reply(socket, "NOTFOUND address does not contain domain");

        auto forward = m_srs.forward(address, domain());

        if (!forward.empty()) {
            if (!boost::iequals(forward, address))
                std::clog << "rewrite " << address << " -> " << forward << std::endl;

            return send_reply(socket, string("OK ") + forward);
        }
        else {
            return send_reply(socket, "PERM srs forwarding failed");
        }
    }
    catch (const std::exception& e) {
        return send_reply(socket, string("NOTFOUND ") + e.what());
    }
}

void srsd_server::reverse(int socket, const string& address)
{
    try {
        if (!m_srs.is_srs(address))
            return send_reply(socket, "NOTFOUND address is not SRS encoded");

        if (address.find_first_of("@") == string::npos)
            return send_reply(socket, "NOTFOUND address does not contain a domain");

        if (!boost::iends_with(address, (string("@") + domain())))
            return send_reply(socket, "NOTFOUND external domains are ignored");

        auto reverse = m_srs.reverse(address);

        if (!reverse.empty()) {
            std::clog << "rewrite " << address << " -> " << reverse << std::endl;
            return send_reply(socket, string("OK ")  + reverse);
        }
        else {
            return send_reply(socket, "NOTFOUND invalid srs email");
        }
    }
    catch (const std::exception& e) {
        return send_reply(socket, string("NOTFOUND ") + e.what());
    }
}

static void send_reply(int socket, const string& reply)
{
    netstring_write(socket, reply);
}
