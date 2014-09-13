AC_DEFUN([AX_REQUIRE_LIB],
         [AC_CHECK_LIB([$1], [$2], [$3], [AC_MSG_ERROR([[$1 not found]])])])
