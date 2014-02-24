# encoding: utf-8

#***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
#**************************************************************************
# File:	clients/save_network.ycp
# Package:	Network configuration
# Summary:	Installation routines
# Authors:	Michal Zugec <mzugec@suse.cz>
#
#
module Yast
  class SaveNetworkClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "NetworkInterfaces"
      Yast.import "FileUtils"
      Yast.import "Netmask"
      Yast.import "NetworkStorage"
      Yast.import "Proxy"
      Yast.import "Installation"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "LanUdevAuto"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/complex.rb"

      # for update system don't copy network from inst_sys (#325738)
      if !Mode.update
        save_network
      else
        Builtins.y2milestone("update - skip save_network")
      end 
      # EOF

      nil
    end


    def CopyConfiguredNetworkFiles
      Builtins.y2milestone(
        "Copy network configuration files from 1st stage into installed system"
      )
      sysconfig = "/etc/sysconfig/network/"
      copy_to = String.Quote(
        Builtins.sformat("%1%2", Installation.destdir, sysconfig)
      )

      # just copy files
      Builtins.foreach(["ifcfg-*", "ifroute-*", "routes"]) do |file|
        copy_from = String.Quote(Builtins.sformat("%1%2", sysconfig, file))
        Builtins.y2milestone("Copy %1 into %2", copy_from, copy_to)
        cmd = Builtins.sformat("cp %1 %2", copy_from, copy_to)
        ret = SCR.Execute(path(".target.bash_output"), cmd)

        Builtins.y2warning("cmd: '#{cmd}' failed: #{ret}") if ret["exit"] != 0
      end

      # merge files with default installed by sysconfig
      Builtins.foreach(["dhcp", "config"]) do |file|
        source_file = Builtins.sformat("%1%2", sysconfig, file)
        dest_file = Builtins.sformat("%1%2", copy_to, file)
        # apply options from initrd configuration files into installed system
        # i.e. just modify (not replace) files from sysconfig rpm
        # FIXME this must be ripped out, refactored and tested
        # In particular, values containing slashes will break the last sed
        cmd2 = "\n" +
          "grep -v \"^[[:space:]]*#\" $source_file | grep = | while read option\n" +
          " do\n" +
          "  key=${option%=*}=\n" +
          "  grep -v \"^[[:space:]]*#\" $dest_file | grep -q $key\n" +
          "  if [ $? != \"0\" ]\n" +
          "   then\n" +
          "    echo \"$option\" >> $dest_file\n" +
          "   else\n" +
          "    sed -i s/\"^[[:space:]]*$key.*\"/\"$option\"/g $dest_file\n" +
          "  fi\n" +
          " done"
        cmd1 = Builtins.sformat(
          "source_file=%1;dest_file=%2\n",
          source_file,
          dest_file
        )
        # merge commands (add file-path variables) because of some sformat limits with % character
        command = Builtins.sformat("%1%2", cmd1, cmd2)
        Builtins.y2milestone(
          "Execute file merging script : %1",
          SCR.Execute(path(".target.bash_output"), command)
        )
      end 
      #FIXME: proxy

      nil
    end



    # this replaces bash script create_interface
    def save_network
      Builtins.y2milestone("starting save_network")
      # skip from chroot
      old_SCR = WFM.SCRGetDefault
      new_SCR = WFM.SCROpen("chroot=/:scr", false)
      WFM.SCRSetDefault(new_SCR)

      # when root is on nfs/iscsi set startmode=nfsroot #176804
      device = NetworkStorage.getDevice(Installation.destdir)
      Builtins.y2debug(
        "%1 directory is on %2 device",
        Installation.destdir,
        device
      )

      if Arch.s390
        Builtins.y2milestone(
          "For s390 architecture copy udev rule files (/etc/udev/rules/51*)"
        )
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p %1/51-* '%2%1'",
            "/etc/udev/rules.d",
            String.Quote(Installation.destdir)
          )
        )
      end
      # --------------------------------------------------------------
      # Copy DHCP client cache so that we can request the same IP (#43974).
      WFM.Execute(
        path(".local.bash"),
        Builtins.sformat(
          "mkdir -p '%2%1'; /bin/cp -p %1/dhcpcd-*.cache '%2%1'",
          "/var/lib/dhcpcd",
          String.Quote(Installation.destdir)
        )
      )
      # Copy DHCPv6 (DHCP for IPv6) client cache.
      WFM.Execute(
        path(".local.bash"),
        Builtins.sformat(
          "/bin/cp -p %1/ '%2%1'",
          "/var/lib/dhcpv6",
          String.Quote(Installation.destdir)
        )
      )

      #Deleting lockfiles and re-triggering udev events for *net is not needed any more
      #(#292375 c#18)

      udev_rules_srcdir = "/etc/udev/rules.d"
      net_srcfile = "70-persistent-net.rules"

      udev_rules_destdir = Builtins.sformat(
        "%1%2",
        String.Quote(Installation.destdir),
        udev_rules_srcdir
      )
      net_destfile = Builtins.sformat(
        "%1%2/%3",
        String.Quote(Installation.destdir),
        udev_rules_srcdir,
        net_srcfile
      )

      Builtins.y2milestone("udev_rules_destdir %1", udev_rules_destdir)
      Builtins.y2milestone("net_destfile %1", net_destfile)

      #Do not create udev_rules_destdir if it already exists (in case of update)
      #(bug #293366, c#7)

      if !FileUtils.Exists(udev_rules_destdir)
        Builtins.y2milestone(
          "%1 does not exist yet, creating it",
          udev_rules_destdir
        )
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat("mkdir -p '%1'", udev_rules_destdir)
        )
      else
        Builtins.y2milestone("File %1 exists", udev_rules_destdir)
      end

      if !FileUtils.Exists(net_destfile)
        Builtins.y2milestone("Copying %1 to the installed system ", net_srcfile)
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p '%1/%2' '%3'",
            udev_rules_srcdir,
            net_srcfile,
            net_destfile
          )
        )
      else
        Builtins.y2milestone("Not copying file %1 - it already exists", net_destfile)
      end

      CopyConfiguredNetworkFiles()

      # close and chroot back
      WFM.SCRSetDefault(old_SCR)
      WFM.SCRClose(new_SCR)

      LanUdevAuto.Write if Mode.autoinst

      SCR.Execute(path(".target.bash"), "chkconfig network on")

      # if portmap running - start it after reboot
      WFM.Execute(
        path(".local.bash"),
        "pidofproc rpcbind && touch /var/lib/YaST2/network_install_rpcbind"
      )

      nil
    end
  end
end

Yast::SaveNetworkClient.new.main
