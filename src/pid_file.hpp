// Copyright (c) 2014, Michael Schout
// Distributed under a 3-clause BSD license. See LICENSE.
#ifndef PID_FILE_HPP
#define PID_FILE_HPP

#include <string>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include "bsd.h"

/**
 * Class representing a PID file
 *
 * Typical Usage:
 * @verbatim
 * pid_file pf;
 * pf.open();
 * daemon(0,0);
 * pf.write();
 * @endverbatim
 * */
class pid_file {
public:
    /**
     * constructor, uses default pid file directory + program name + .pid
     */
    pid_file() :
        m_path(std::string(PIDDIR "/") + getprogname() + ".pid"),
        m_mode(0644),
        m_fd(-1),
        m_inode(-1),
        m_dev(-1) {};

    /**
     * constuctor. uses given path to pid file and mode.
     * @param path the full path to the pid file
     * @param mode the file mode
     */
    pid_file(const std::string path, mode_t mode=0644) :
        m_path(!path.empty()
                ? path
                : std::string(PIDDIR "/") + getprogname() + ".pid"),
        m_mode(mode),
        m_fd(-1),
        m_inode(-1),
        m_dev(-1) {};

    /**
     * open the pid file and obtain an exclusive lock on it.
     */
    void open();

    /**
     * write the pid file.
     */
    bool write();

    /**
     * close the pid file
     */
    bool close();

    /**
     * verify the pid file
     */
    bool verify();

    /**
     * remove the pid file
     */
    bool remove();

    /**
     * get the path to the pid file
     */
    std::string path() { return m_path; }

    /**
     * set the pid file path.
     * @throws std::runtime_error if the pid file is already open
     */
    void path(const std::string& path);

    /**
     * set the directory to the pid file
     * @throws std::runtime_error if the pid file is already open
     */
    void dir(const std::string& dir);

    /**
     * destroys the pid file object
     * @note this will try to remove the pid file if it exists
     */
    ~pid_file();

private:
    std::string m_path;
    int m_fd;
    mode_t m_mode;
    ino_t m_inode;
    dev_t m_dev;
};

#endif
