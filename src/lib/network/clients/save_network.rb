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

require "network/network_autoconfiguration"
require "network/network_autoyast"
require "y2network/proposal_settings"
require "y2network/config_copier"

Yast.import "Installation"
Yast.import "DNS"
Yast.import "Mode"
Yast.import "Arch"

module Yast
  class SaveNetworkClient < Client
    include Logger

    def initialize
      textdomain "network"
    end

    def main
      # for update system don't copy network from inst_sys (#325738)
      return save_network if !Mode.update

      log.info("update - skip save_network")

      nil
    end

  private

    ETC = "/etc".freeze
    NETWORK_MANAGER = "/etc/NetworkManager".freeze

    COMMON_FILES = [
      { dir: ETC, file: DNSClass::HOSTNAME_FILE },
      { dir: ETC, file: "hosts" },
      # Copy sysctl file as network writes there ip forwarding (bsc#1159295)
      { dir: ::File.join(ETC, "sysctl.d"), file: "70-yast.conf" }
    ].freeze

    # Directory containing udev rules
    UDEV_RULES_DIR = "/etc/udev/rules.d".freeze
    PERSISTENT_RULES = "70-persistent-net.rules".freeze

    def copy_udev_rules
      copy_files_to_target([PERSISTENT_RULES], UDEV_RULES_DIR)

      return unless Arch.s390

      # chzdev creates the rules starting with "41-"
      log.info("Copy S390 specific udev rule files (/etc/udev/rules/41*)")
      copy_files_to_target(["41-*"], UDEV_RULES_DIR)

      nil
    end

    # Run a block in the instsys
    #
    # @param block [Proc] Block to run in instsys
    def on_local(&block)
      # skip from chroot
      old_SCR = WFM.SCRGetDefault
      new_SCR = WFM.SCROpen("chroot=/:scr", false)
      WFM.SCRSetDefault(new_SCR)

      block.call

      # close and chroot back
      WFM.SCRSetDefault(old_SCR)
      WFM.SCRClose(new_SCR)
    end

    # Copies the configuration created during installation to the target system only when it is
    # needed
    #
    # Copies several config files which should be preserved when installation
    # is done. E.g. ifcfg-* files, custom udev rules and so on.
    def copy_from_instsys
      on_local do
        # The s390 devices activation was part of the rules handling.
        NetworkAutoYast.instance.activate_s390_devices if Mode.autoinst && Arch.s390

        # this has to be done here (out of chroot) bcs:
        # 1) udev agent doesn't support SetRoot
        # 2) original ifcfg file is copied otherwise too. It doesn't break things itself
        # but definitely not looking well ;-)
        copy_udev_rules
        return if Mode.autoinst && !Lan.autoinst.copy_network?

        log.info("Copy network configuration files from 1st stage into installed system")
        copy_dhcp_info
        COMMON_FILES.each { |e| copy_files_to_target([e[:file]], e[:dir]) }
      end

      # The backend need to be evaluated inside the chroot due to package installation checking
      copy_backend_config

      nil
    end

    # For copying dhcp-client leases
    # FIXME: We probably could omit the copy of these leases as we are using
    # wicked during the installation instead of dhclient.
    DHCPV4_PATH = "/var/lib/dhcp/".freeze
    DHCPV6_PATH = "/var/lib/dhcp6/".freeze
    DHCP_FILES = ["*.leases"].freeze

    # Convenience method for copying dhcp files
    def copy_dhcp_info
      copy_files_to_target(DHCP_FILES, DHCPV4_PATH)
      copy_files_to_target(DHCP_FILES, DHCPV6_PATH)
    end

    def copy_backend_config
      return unless proposal_backend

      log.info("Copying #{proposal_backend} specific config to the target system.")
      Y2Network::ConfigCopier.for(proposal_backend)&.copy
    end

    # Make unit testing possible
    ROOT_PATH = "/".freeze

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
      # Do not apply changes at the end of the first stage.
      Yast::Lan.write_only = true
      copy_udev_rules if Mode.autoinst && NetworkAutoYast.instance.configure_lan

      # FIXME: Really make sense to configure it in autoinst mode? At least the
      # proposal should be done and checked after lan configuration and in case
      # that a bridge configuration is present in the profile it should be
      # skipped or even only done in case of missing `networking -> interfaces`
      # section
      NetworkAutoconfiguration.instance.configure_virtuals if propose_virt_config?

      if !Mode.autoinst
        NetworkAutoconfiguration.instance.configure_dns
        NetworkAutoconfiguration.instance.configure_routing
        configure_network_manager
      end

      # this depends on DNS configuration
      configure_hosts
    end

    def proposal_backend
      Y2Network::ProposalSettings.instance.network_service
    end

    # Configures NetworkManager
    #
    # When running the live installation, it is just a matter of copying
    # system-connections to the installed system. In a regular installation,
    # write the settings in the Yast::Lan.yast_config object.
    def configure_network_manager
      return unless proposal_backend == :network_manager

      if Yast::Lan.system_config.backend&.id == :network_manager
        copy_backend_config
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

      # TODO: Still needed? Why the service is not enabled?
      # if rpcbind running - start it after reboot (bsc#423026)
      WFM.Execute(
        path(".local.bash"),
        "/sbin/pidofproc rpcbind && /usr/bin/touch /var/lib/YaST2/network_install_rpcbind"
      )

      nil
    end

    # Sets default network service
    def set_network_service
      log.info("Setting target system network service")

      # NetworkServices caches the selected backend. That is, it assumes the
      # state in the inst-sys and the chroot is the same but that is not true
      # at all specially in a live installation where NM is the backend by
      # default. For detecting changes we should reset the cache first.
      NetworkService.reset!
      # Ensure not selected backend is disabled in order to not end with two network backends
      # running at the same time. (bsc#1202479)
      NetworkService.send(:disable_service, :wicked)
      NetworkService.send(:disable_service, :network_manager)
      case proposal_backend
      when :network_manager
        log.info("- using NetworkManager")
        NetworkService.use_network_manager
      when :wicked
        log.info("- using wicked")
        NetworkService.use_wicked
      when :none
        return
      end

      # Force the enablement of the selected backend just in case no modifications was detected but
      # the backend was not enabled at all. (bsc#1202479)
      NetworkService.EnableDisableNow(force: true)
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
