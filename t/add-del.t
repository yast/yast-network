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

echo "# assume and check that eth0 exists, as a base for the vlan"
ip addr show dev eth0
echo "ok 1 eth0: exists already"

echo "# add a (virtual) interface"
$YAST lan add name=vlan50 ethdevice=eth0 bootproto=dhcp
echo "ok 2 vlan50: added"

# check it has worked
ip addr show dev vlan50 || tapfail
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
