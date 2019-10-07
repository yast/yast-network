#!/bin/sh

# Copyright (c) [2019] SUSE LLC
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
echo 1..8

# usage:
#  foo || tapfail
#  echo "ok"
# this will tell TAP "not ok" IF foo has failed
tapfail() {
  echo -n "not "
}

echo "# check if wicked runs"
rcwicked status || tapfail
echo "ok 1 wicked running"

YAST=/usr/sbin/yast

echo "# find the base device for the vlan"
BASEDEVICE=$(ip -o addr show scope global | head -n1 | cut -d' ' -f2)
ip addr show dev $BASEDEVICE || tapfail
echo "ok 2 $BASEDEVICE: found"

echo "# add a (virtual) interface"
$YAST lan add name=vlan50 type=vlan ethdevice=$BASEDEVICE bootproto=dhcp || tapfail
echo "ok 3 vlan50: added"

# check it has worked
ip addr show dev vlan50
echo "ok 4 vlan50: interface exists"

ls /etc/sysconfig/network/ifcfg-vlan50 || tapfail
echo "ok 5 vlan50: ifcfg exists"

echo "# find it and delete it"
# the embarassing part: no way to identify by "vlan50"
ID=$($YAST lan list |& grep vlan50 | cut -f1)
$YAST lan delete id=$ID verbose || tapfail
echo "ok 6 vlan50: deleted"

# how to assert nonexistence?
! ip addr show dev vlan50 || tapfail
echo "ok 7 vlan50: interface does not exist"

! ls /etc/sysconfig/network/ifcfg-vlan50 || tapfail
echo "ok 8 vlan50: ifcfg does not exist"
