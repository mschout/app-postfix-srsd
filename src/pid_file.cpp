// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdexcept>
#include <iostream>
#include "bsd.h"
#include "pid_file.hpp"
#include "config.h"
#include "srsd/system_error.hpp"

using std::string;
using std::endl;
using std::runtime_error;

void
pid_file::path(const std::string& path)
{
    if (m_fd != -1)
        throw runtime_error("cannot change path on open pid file!");

    m_path = path;
}

void
pid_file::dir(const std::string& dir)
{
    string newdir = dir;

    if (!(newdir.back() == '/'))
        newdir.push_back('/');

    path(newdir + getprogname() + ".pid");
}

void
pid_file::open()
{
    struct stat sb;

    // open the PID file and obtain exclusive lock.
    m_fd = flopen(m_path.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC | O_NONBLOCK, m_mode);
    if (m_fd == -1 && errno == EWOULDBLOCK)
        throw runtime_error("already running");

    // remember file information so that write() is sure to write to the proper descriptor

    if (fstat(m_fd, &sb) == -1) {
        unlink(m_path.c_str());
        ::close(m_fd);
        throw srsd::system_error("failed to stat pid file");
    }

    m_dev = sb.st_dev;
    m_inode = sb.st_ino;
}

bool
pid_file::write()
{
    if (!verify())
        return false;

    if (ftruncate(m_fd, 0) == -1)
        throw srsd::system_error("failed to truncate pid file");

    string pid = std::to_string(getpid());

    if (pwrite(m_fd, pid.c_str(), pid.length(), 0) != pid.length())
        throw srsd::system_error("failed to write to pid file");

    return true;
}

bool
pid_file::close()
{
    if (!verify())
        return false;

    if (::close(m_fd) == -1)
        throw srsd::system_error("failed to close pid file");

    return true;
}

bool
pid_file::verify()
{
    struct stat sb;

    if (m_fd == -1)
        return false;

    if (fstat(m_fd, &sb) == -1)
        return false;

    // BSD does EDOOFUS here
    if (sb.st_dev != m_dev || sb.st_ino != m_inode)
        return false;

    return true;
}

bool
pid_file::remove()
{
    if (!verify())
        return false;

    if (unlink(m_path.c_str()) == -1)
        throw srsd::system_error("unlink pid file failed");

    if (::close(m_fd) == -1)
        throw srsd::system_error("close pid file failed");

    // reset fd/inode/dev
    m_fd = -1;
    m_inode = -1;
    m_dev = -1;

    return true;
}

pid_file::~pid_file()
{
    remove();
}
