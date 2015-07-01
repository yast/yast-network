#!/bin/sh
# a TAP compatible test

# quick and dirty: fail early
set -eu

# test plan
echo 1..2

# usage:
#  foo || tapfail
#  echo "ok"
# this will tell TAP "not ok" IFF foo has failed
tapfail() {
  echo -n "not "
}

YAST=/usr/sbin/yast

! $YAST lan no-such-command || tapfail
echo "ok 1 no-such-command: returns error"

# previously an error code would be reported but exception hidden in the log
$YAST lan please-crash |& grep -E "Internal error|backtrace" || tapfail
echo "ok 2 no-such-command: reports exception"
