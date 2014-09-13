AC_DEFUN([AX_REQUIRE_HEADER],
         [AC_CHECK_HEADERS([$1], [$2], [AC_MSG_ERROR([[$1 not found]])])])
