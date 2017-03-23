#!/bin/sh
# a TAP compatible test

# quick and dirty: fail early
set -eu

# test plan
echo 1..7

# usage:
#  foo || tapfail
#  echo "ok"
# this will tell TAP "not ok" IF foo has failed
tapfail() {
  echo -n "not "
}

YAST=/usr/sbin/yast

echo "# find the base device for the vlan"
BASEDEVICE=$(ip -o addr show scope global | head -n1 | cut -d' ' -f2)
ip addr show dev $BASEDEVICE
echo "ok 1 $BASEDEVICE: found"

echo "# add a (virtual) interface"
$YAST lan add name=vlan50 ethdevice=$BASEDEVICE bootproto=dhcp || tapfail
echo "ok 2 vlan50: added"

# check it has worked
ip addr show dev vlan50
echo "ok 3 vlan50: interface exists"

ls /etc/sysconfig/network/ifcfg-vlan50 || tapfail
echo "ok 4 vlan50: ifcfg exists"

echo "# find it and delete it"
# the embarassing part: no way to identify by "vlan50"
ID=$($YAST lan list |& grep Virtual.LAN | cut -f1)
$YAST lan delete id=$ID verbose || tapfail
echo "ok 5 vlan50: deleted"

# how to assert nonexistence?
! ip addr show dev vlan50 || tapfail
echo "ok 6 vlan50: interface does not exist"

! ls /etc/sysconfig/network/ifcfg-vlan50 || tapfail
echo "ok 7 vlan50: ifcfg does not exist"
