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

require "y2storage"
require "network/install_inf_convertor"
require "network/network_autoconfiguration"
require "network/network_autoyast"
require "y2network/proposal_settings"

require "cfa/generic_sysconfig"

require "shellwords"

module Yast
  class SaveNetworkClient < Client
    include Logger

    def main
      textdomain "network"

      Yast.import "DNS"
      Yast.import "FileUtils"
      Yast.import "Installation"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "Arch"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/complex.rb"

      # for update system don't copy network from inst_sys (#325738)
      if !Mode.update
        save_network
      else
        Builtins.y2milestone("update - skip save_network")
      end

      nil
    end

  private

    # Updates ifcfg file as needed when the "/" filesystem is accessed over network
    #
    # @param file [String] ifcfg name
    def adjust_for_network_disks(file)
      # storage-ng
      # Check if installation is targeted to a remote destination.
      devicegraph = Y2Storage::StorageManager.instance.staging
      is_disk_in_network = devicegraph.filesystem_in_network?("/")

      if !is_disk_in_network
        log.info("Root filesystem is not on a network based device")
        return
      end

      log.info("Root filesystem is on a network based device")

      # tune ifcfg file for remote filesystem
      SCR.Execute(
        path(".target.bash"),
        "/usr/bin/sed -i s/^[[:space:]]*STARTMODE=.*/STARTMODE='nfsroot'/ #{file.shellescape}"
      )
    end

    ETC = "/etc".freeze
    SYSCONFIG = "/etc/sysconfig/network".freeze
    NETWORK_MANAGER = "/etc/NetworkManager".freeze
    # Make unit testing possible
    ROOT_PATH = "/".freeze

    def CopyConfiguredNetworkFiles
      return if Mode.autoinst && !Lan.autoinst.copy_network?

      log.info(
        "Copy network configuration files from 1st stage into installed system"
      )

      inst_dir = Installation.destdir

      copy_recipes = [
        { dir: SYSCONFIG, file: "ifcfg-*" },
        { dir: SYSCONFIG, file: "ifroute-*" },
        { dir: SYSCONFIG, file: "routes" },
        { dir: ::File.join(ETC, "wicked"), file: "common.xml" },
        { dir: ETC, file: DNSClass::HOSTNAME_FILE },
        { dir: ETC, file: "hosts" },
        # Copy sysctl file as network writes there ip forwarding (bsc#1159295)
        { dir: ::File.join(ETC, "sysctl.d"), file: "70-yast.conf" }
      ]

      # just copy files
      copy_recipes.each do |recipe|
        # can be shell pattern like ifcfg-*
        file_pattern = ::File.join(ROOT_PATH, recipe[:dir], recipe[:file])
        copy_to = ::File.join(inst_dir, recipe[:dir])
        log.info("Processing copy recipe #{file_pattern.inspect}")

        Dir.glob(file_pattern).each do |file|
          adjust_for_network_disks(file) if file.include?("ifcfg-")

          copy_from = file

          log.info("Copying #{copy_from} to #{copy_to}")

          cmd = "cp #{copy_from.shellescape} #{copy_to.shellescape}"
          ret = SCR.Execute(path(".target.bash_output"), cmd)

          log.warn("cmd: '#{cmd}' failed: #{ret}") if ret["exit"] != 0
        end
      end

      copy_to = String.Quote(::File.join(inst_dir, SYSCONFIG))

      # merge files with default installed by sysconfig
      ["dhcp", "config"].each do |file|
        modified_file = ::File.join(ROOT_PATH, SYSCONFIG, file)
        dest_file = ::File.join(copy_to, file)
        CFA::GenericSysconfig.merge_files(dest_file, modified_file)
      end
      # FIXME: proxy

      nil
    end

    # Directory containing udev rules
    UDEV_RULES_DIR = "/etc/udev/rules.d".freeze

    def copy_udev_rules
      dest_root = String.Quote(Installation.destdir)

      # Deleting lockfiles and re-triggering udev events for *net is not needed any more
      # (#292375 c#18)

      udev_rules_srcdir = File.join(ROOT_PATH, UDEV_RULES_DIR)
      net_srcfile = "70-persistent-net.rules"

      udev_rules_destdir = dest_root + UDEV_RULES_DIR
      net_destfile = dest_root + UDEV_RULES_DIR + "/" + net_srcfile

      log.info("udev_rules_destdir #{udev_rules_destdir}")
      log.info("net_destfile #{net_destfile}")

      # Do not create udev_rules_destdir if it already exists (in case of update)
      # (bug #293366, c#7)

      if !FileUtils.Exists(udev_rules_destdir)
        log.info("#{udev_rules_destdir} does not exist yet, creating it")
        WFM.Execute(
          path(".local.bash"),
          "/usr/bin/mkdir -p #{udev_rules_destdir.shellescape}"
        )
      else
        log.info("File #{udev_rules_destdir} exists")
      end

      if Arch.s390
        # chzdev creates the rules starting with "41-"
        log.info("Copy S390 specific udev rule files (/etc/udev/rules/41*)")

        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p %1/41-* '%2%3'",
            File.join(ROOT_PATH, UDEV_RULES_DIR),
            dest_root.shellescape,
            UDEV_RULES_DIR
          )
        )
      end

      if !Mode.update
        log.info("Copying #{net_srcfile} to the installed system ")
        WFM.Execute(
          path(".local.bash"),
          "/bin/cp -p #{udev_rules_srcdir.shellescape}/#{net_srcfile.shellescape} " \
            "#{net_destfile.shellescape}"
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

      # this has to be done here (out of chroot) bcs:
      # 1) udev agent doesn't support SetRoot
      # 2) original ifcfg file is copied otherwise too. It doesn't break things itself
      # but definitely not looking well ;-)
      # TODO: implement support for create udev rules if needed

      # The s390 devices activation was part of the rules handling.
      NetworkAutoYast.instance.activate_s390_devices if Mode.autoinst && Arch.s390

      copy_dhcp_info
      copy_udev_rules
      CopyConfiguredNetworkFiles()

      # close and chroot back
      WFM.SCRSetDefault(old_SCR)
      WFM.SCRClose(new_SCR)

      nil
    end

    # For copying wicked dhcp files (bsc#1082832)
    WICKED_DHCP_PATH = "/var/lib/wicked/".freeze
    WICKED_DHCP_FILES = ["duid.xml", "iaid.xml", "lease*.xml"].freeze
    # For copying dhcp-client leases
    # FIXME: We probably could omit the copy of these leases as we are using
    # wicked during the installation instead of dhclient.
    DHCPV4_PATH = "/var/lib/dhcp/".freeze
    DHCPV6_PATH = "/var/lib/dhcp6/".freeze
    DHCP_FILES = ["*.leases"].freeze

    # Convenience method for copying dhcp files
    def copy_dhcp_info
      entries_to_copy = [
        { dir: WICKED_DHCP_PATH, files: WICKED_DHCP_FILES },
        { dir: DHCPV4_PATH, files: DHCP_FILES },
        { dir: DHCPV6_PATH, files: DHCP_FILES }
      ]

      entries_to_copy.each { |e| copy_files_to_target(e[:files], e[:dir]) }
    end

    # Convenvenience method for copying a list of files into the target system.
    # It takes care of creating the target directory but only if some file
    # needs to be copied
    #
    # @param files [Array<String>] list of short filenames to be copied
    # @param path [String] path where the files resides and where will be
    # copied in the target system
    # @return [Boolean] whether some file was copied
    def copy_files_to_target(files, path)
      dest_dir = ::File.join(Installation.destdir, path)
      glob_files = ::Dir.glob(files.map { |f| File.join(ROOT_PATH, path, f) })
      return false if glob_files.empty?

      ::FileUtils.mkdir_p(dest_dir)
      ::FileUtils.cp(glob_files, dest_dir, preserve: true)
      true
    end

    # Creates target's /etc/hosts configuration
    #
    # It uses hosts' configuration as defined in AY profile (if any) or
    # proceedes according the proposal
    def configure_hosts
      configured = false
      configured = NetworkAutoYast.instance.configure_hosts if Mode.autoinst
      NetworkAutoconfiguration.instance.configure_hosts if !configured
    end

    # Invokes configuration according automatic proposals or AY profile
    #
    # It creates a proposal in case of common installation. In case of AY
    # installation it does full import of <networking> section
    def configure_lan
      copy_udev_rules if Mode.autoinst && NetworkAutoYast.instance.configure_lan

      # FIXME: Really make sense to configure it in autoinst mode? At least the
      # proposal should be done and checked after lan configuration and in case
      # that a bridge configuration is present in the profile it should be
      # skipped or even only done in case of missing `networking -> interfaces`
      # section
      NetworkAutoconfiguration.instance.configure_virtuals if propose_virt_config?

      if !Mode.autoinst
        NetworkAutoconfiguration.instance.configure_dns
        configure_network_manager
      end

      # this depends on DNS configuration
      configure_hosts
    end

    # Configures NetworkManager
    #
    # When running the live installation, it is just a matter of copying
    # system-connections to the installed system. In a regular installation,
    # write the settings in the Yast::Lan.yast_config object.
    def configure_network_manager
      return unless Y2Network::ProposalSettings.instance.network_service == :network_manager

      if Yast::Lan.system_config.backend&.id == :network_manager
        copy_files_to_target(["*"], File.join(NETWORK_MANAGER, "system-connections"))
      else
        Yast::Lan.yast_config.backend = :network_manager
        Yast::Lan.write_config
      end
    end

    # Convenience method to check whether a bridge network configuration for
    # virtualization should be proposed or not
    def propose_virt_config?
      Y2Network::ProposalSettings.instance.virt_bridge_proposal
    end

    # It does an automatic configuration of installed system
    #
    # Basically, it runs several proposals.
    def configure_target
      # creates target's network configuration
      configure_lan

      # set proper network service
      set_network_service

      # if portmap running - start it after reboot
      WFM.Execute(
        path(".local.bash"),
        "/sbin/pidofproc rpcbind && /usr/bin/touch /var/lib/YaST2/network_install_rpcbind"
      )

      nil
    end

    # Sets default network service
    def set_network_service
      if Mode.autoinst
        NetworkAutoYast.instance.set_network_service
        return
      end

      log.info("Setting network service according to product preferences")

      backend = Y2Network::ProposalSettings.instance.network_service
      # NetworkServices caches the selected backend. That is, it assumes the
      # state in the inst-sys and the chroot is the same but that is not true
      # at all specially in a live installation where NM is the backend by
      # default. For detecting changes we should reset the cache first.
      NetworkService.reset!
      case backend
      when :network_manager
        log.info("- using NetworkManager")
        NetworkService.use_network_manager
      else
        log.info("- using wicked")
        NetworkService.use_wicked
      end

      NetworkService.EnableDisableNow
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
