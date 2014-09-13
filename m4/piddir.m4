AC_DEFUN([AX_PIDDIR],
[
    piddir=/var/run

    AC_ARG_WITH([pid-dir],
        AS_HELP_STRING([--with-pid-dir],
            [directory where PID files are saved]
        ),
        [
            piddir="$withval"
        ],
        [
        ]
    )

    AC_SUBST([PIDDIR], [$piddir])
])
