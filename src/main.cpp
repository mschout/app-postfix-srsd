// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include <iostream>
#include <boost/program_options.hpp>
#include "slogstream.hpp"
#include "pid_file.hpp"
#include "srsd/system_error.hpp"
#include "srsd_server.hpp"

#include <sys/types.h>
#include <pwd.h>
#include <grp.h>

using std::string;
namespace po = boost::program_options;

void parse_options(int argc, char *argv[]);
int daemonize();
void usage();

po::variables_map vm;
po::options_description desc("Allowed options");

int main(int argc, char *argv[]) 
{
    parse_options(argc, argv);

    // handle case where all required args, PLUS --help given
    if (vm.count("help"))
        usage();

    pid_file pid;

    try {
        if (!vm.count("debug")) {
            // open syslog
            slogstream::open(std::clog, LOG_MAIL);

            // write pid file and deamonize
            pid.path(vm["pidfile"].as<string>());
            pid.open();
            daemonize();
            pid.write();
        }

        srsd_server server(vm["socket"].as<string>(), vm["domain"].as<string>());

        server.load_secrets(vm["secrets"].as<string>());
        server.bind();
        server.drop_privileges(vm["user"].as<string>(), vm["group"].as<string>());
        server.run();
    }
    catch (const std::exception& e) {
        std::clog << "Error: " << e.what() << std::endl;
    }

    return 0;
}

void usage()
{
    std::cout << "Usage: " << getprogname() << " [options]" << std::endl
        << std::endl
        << desc;

    exit(1);
}

void parse_options(int argc, char *argv[])
{
    desc.add_options()
        ("debug,d",   "run in debug mode")
        ("help,h",  "Print this help message")
        ("socket",  po::value<string>()->required(), "path to the unix socket file")
        ("secrets", po::value<string>()->required(), "path to the secrets file")
        ("user",    po::value<string>()->default_value("nobody"),
            "username to run as")
        ("group",   po::value<string>()->default_value("nobody"),
            "group to run as")
        ("domain",  po::value<string>()->required(), "SRS rewrite domain")
        ("pidfile", po::value<string>()->default_value(string(PIDDIR) + "/" + getprogname() + ".pid"),
            "path to the pid file")
    ;

    try {
        po::store(po::parse_command_line(argc, argv, desc), vm);
        po::notify(vm);
    }
    catch (po::required_option& e) {
        if (!vm.count("help"))
            std::cout << "ERROR: required option " << e.get_option_name() << " is missing!" << std::endl;

        usage();
    }
}

int daemonize()
{
    int noclose = vm.count("debug") ? 0 : 1;

    if (daemon(0, noclose) < 0)
        throw std::runtime_error("daemon() failed");

    return 0;
}
