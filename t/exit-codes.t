#!/bin/sh

# Copyright (c) [2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

# a TAP compatible test

# quick and dirty: fail early
set -eu

# test plan
echo 1..1

# usage:
#  foo || tapfail
#  echo "ok"
# this will tell TAP "not ok" IF foo has failed
tapfail() {
  echo -n "not "
}

YAST=/usr/sbin/yast

TEST="1 An unknown command produces an error exit code"
echo "# $TEST"
! $YAST lan nosuchcommand || tapfail
echo "ok $TEST"
