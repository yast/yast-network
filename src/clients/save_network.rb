# encoding: utf-8

# ***************************************************************************
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
# **************************************************************************
# File:	clients/save_network.ycp
# Package:	Network configuration
# Summary:	Installation routines
# Authors:	Michal Zugec <mzugec@suse.cz>
#
#
module Yast
  require "network/install_inf_convertor"
  require "network/network_autoconfiguration"

  class SaveNetworkClient < Client
    include Logger

    def main
      Yast.import "UI"

      textdomain "network"

      Yast.import "DNS"
      Yast.import "FileUtils"
      Yast.import "NetworkStorage"
      Yast.import "Installation"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "Storage"
      Yast.import "LanItems"
      Yast.import "Profile"
      Yast.import "Linuxrc"

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

    def adjust_for_network_disks(file)
      # Check if installation is targeted to a remote destination.
      # Discover remote access method here - { :nfs, :iscsi, :fcoe }
      # or :no when no remote storage
      remote_access = Storage.IsDeviceOnNetwork(
        NetworkStorage.getDevice(Installation.destdir)
      )

      log.info("Network based device: #{remote_access}")

      return if remote_access == :no

      # tune ifcfg file for remote filesystem
      SCR.Execute(
        path(".target.bash"),
        "sed -i s/^[[:space:]]*STARTMODE=.*/STARTMODE='nfsroot'/ #{file}"
      )
    end

    ETC = "/etc/"
    SYSCONFIG = "/etc/sysconfig/network/"

    def CopyConfiguredNetworkFiles
      log.info(
        "Copy network configuration files from 1st stage into installed system"
      )

      inst_dir = Installation.destdir

      copy_receipts = [
        { dir: SYSCONFIG, file: "ifcfg-*" },
        { dir: SYSCONFIG, file: "ifroute-*" },
        { dir: SYSCONFIG, file: "routes" },
        { dir: ETC + "wicked/", file: "common.xml" },
        { dir: ETC, file: DNSClass::HOSTNAME_FILE }
      ]

      # just copy files
      copy_receipts.each do |receipt|
        file = receipt[:dir] + receipt[:file]
        adjust_for_network_disks(file) if file.include?("ifcfg-")

        copy_from = String.Quote(file)
        copy_to = String.Quote(inst_dir + receipt[:dir])

        log.info("Copying #{copy_from} to #{copy_to}")

        cmd = "cp " << copy_from << " " << copy_to
        ret = SCR.Execute(path(".target.bash_output"), cmd)

        log.warn("cmd: '#{cmd}' failed: #{ret}") if ret["exit"] != 0
      end

      copy_to = String.Quote(inst_dir + SYSCONFIG)

      # merge files with default installed by sysconfig
      ["dhcp", "config"].each do |file|
        source_file = SYSCONFIG + file
        dest_file = copy_to + file
        # apply options from initrd configuration files into installed system
        # i.e. just modify (not replace) files from sysconfig rpm
        # FIXME: this must be ripped out, refactored and tested
        # In particular, values containing slashes will break the last sed
        command = "\n" \
          "source_file=#{source_file};dest_file=#{dest_file}\n" \
          "grep -v \"^[[:space:]]*#\" $source_file | grep = | while read option\n" \
          " do\n" \
          "  key=${option%=*}=\n" \
          "  grep -v \"^[[:space:]]*#\" $dest_file | grep -q $key\n" \
          "  if [ $? != \"0\" ]\n" \
          "   then\n" \
          "    echo \"$option\" >> $dest_file\n" \
          "   else\n" \
          "    sed -i s/\"^[[:space:]]*$key.*\"/\"$option\"/g $dest_file\n" \
          "  fi\n" \
          " done"
        ret = SCR.Execute(path(".target.bash_output"), command)

        log.error("Execute file merging script failed: #{ret}") if ret["exit"] != 0
      end
      # FIXME: proxy

      nil
    end

    def copy_udev_rules
      dest_root = String.Quote(Installation.destdir)

      if Arch.s390
        log.info("Copy S390 specific udev rule files (/etc/udev/rules/51*)")

        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p %1/51-* '%2%1'",
            "/etc/udev/rules.d",
            dest_root
          )
        )
      end

      # Deleting lockfiles and re-triggering udev events for *net is not needed any more
      # (#292375 c#18)

      udev_rules_srcdir = "/etc/udev/rules.d"
      net_srcfile = "70-persistent-net.rules"

      udev_rules_destdir = dest_root + udev_rules_srcdir
      net_destfile = dest_root + udev_rules_srcdir + "/" + net_srcfile

      log.info("udev_rules_destdir #{udev_rules_destdir}")
      log.info("net_destfile #{net_destfile}")

      # Do not create udev_rules_destdir if it already exists (in case of update)
      # (bug #293366, c#7)

      if !FileUtils.Exists(udev_rules_destdir)
        log.info("#{udev_rules_destdir} does not exist yet, creating it")
        WFM.Execute(
          path(".local.bash"),
          "mkdir -p '#{udev_rules_destdir}'"
        )
      else
        log.info("File #{udev_rules_destdir} exists")
      end

      if !Mode.update
        log.info("Copying #{net_srcfile} to the installed system ")
        WFM.Execute(
          path(".local.bash"),
          "/bin/cp -p '#{udev_rules_srcdir}/#{net_srcfile}' '#{net_destfile}'"
        )
      else
        log.info("Not copying file #{net_destfile} - update mode")
      end

      nil
    end

    # Copies parts configuration created during installation.
    #
    # Copies several config files which should be preserved when installation
    # is done. E.g. ifcfg-* files, custom udev rules and so on.
    def copy_from_instsys
      # skip from chroot
      old_SCR = WFM.SCRGetDefault
      new_SCR = WFM.SCROpen("chroot=/:scr", false)
      WFM.SCRSetDefault(new_SCR)

      ay_mode_configuration if Mode.autoinst

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

      copy_udev_rules
      CopyConfiguredNetworkFiles()

      # close and chroot back
      WFM.SCRSetDefault(old_SCR)
      WFM.SCRClose(new_SCR)

      nil
    end

    # It does an automatic configuration of installed system
    #
    # Basically, it runs several proposals.
    def configure_target
      NetworkAutoconfiguration.instance.configure_virtuals
      NetworkAutoconfiguration.instance.configure_dns
      NetworkAutoconfiguration.instance.configure_hosts

      DNS.create_hostname_link

      SCR.Execute(path(".target.bash"), "chkconfig network on")

      # if portmap running - start it after reboot
      WFM.Execute(
        path(".local.bash"),
        "pidofproc rpcbind && touch /var/lib/YaST2/network_install_rpcbind"
      )

      nil
    end

    # Applies part of AY configuration at the end of first stage
    #
    # Intended mainly for steps which cannot be done in AY's second stage
    #
    # FIXME: Currently used only for applying udev rules during network
    # installations (ssh, vnc, ...). It was introduced as a quick fix for
    # bnc#944349, so it is currently limited only on {ssh|vnc} installations.
    # Once properly analyzed and tested then starting of whole network second
    # stage can be moved here.
    def ay_mode_configuration
      return if !Mode.autoinst
      return if !(Linuxrc.usessh || Linuxrc.vnc)

      ay_profile = Profile.current

      log.info("Applying udev rules according AY profile")

      return if ay_profile.nil? || ay_profile.empty?
      return if ay_profile["networking"].nil? || ay_profile["networking"].empty?

      udev_rules = ay_profile["networking"]["net-udev"]
      log.info("- udev rules: #{udev_rules}")

      return if udev_rules.nil? || udev_rules.empty?

      LanItems.Read

      udev_rules.each do |rule|
        name_to = rule["name"]
        attr = rule["rule"]
        key = rule["value"].downcase
        # currently we're interrested only on those interfaces which are already
        # configured - such interfaces cannot be restarted during second stage
        item, matching_item = LanItems.Items.find { |_, i| i["hwinfo"]["busid"].downcase == key || i["hwinfo"]["mac"].downcase == key }
        next if !matching_item

        # for logging only
        name_from = matching_item["ifcfg"] || matching_item["dev_name"]
        log.info("- renaming <#{name_from}> -> <#{name_to}>")

        # selecting according device name is unreliable (selects only in between configured devices)
        LanItems.current = item

        # find out what attribude is currently used for setting device name and
        # change it if needed. Currently mac is used by default. So, we check is it is
        # the other one (busid). If no we defaults to mac.
        bus_attr = LanItems.GetItemUdev("KERNELS")
        current_attr = bus_attr.empty? ? "ATTR{address}" : "KERNELS"

        # make sure that we base renaming on defined attribute with value given in AY profile
        LanItems.ReplaceItemUdev(current_attr, attr, key)
        LanItems.rename(name_to)
      end

      LanItems.write
    end

    # this replaces bash script create_interface
    def save_network
      log.info("starting save_network")

      copy_from_instsys
      configure_target

      nil
    end
  end
end

Yast::SaveNetworkClient.new.main
