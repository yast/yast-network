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

require "yast"
require "network/wicked"
require "y2network/interface_config_builder"

require "shellwords"

module Yast
  # The class is responsible for generating / proposing automatic
  # configuration during installation workflow
  class NetworkAutoconfiguration
    include Wicked
    include Singleton
    include Logger

    BASH_PATH = Path.new(".target.bash")

    def initialize
      Yast.import "Lan"
      Yast.import "Package"
      Yast.import "DNS"
      Yast.import "Arch"
      Yast.import "Host"
    end

    # Checks if any of available interfaces is configured and active
    #
    # returns [Boolean] true when at least one interface is active
    def any_iface_active?
      Yast::Lan.Read(:cache)
      config.interfaces.any? do |interface|
        return false unless active_config?(interface.name)

        config.connections.by_name(interface.name) || ibft_interfaces.include?(interface.name)
      end
    end

    # Return true if the given interface is connected but it is not configured by iBFT or via an
    # ifcfg file.
    #
    # Note: (it speeds up the initialization phase of installer - bnc#872319)
    # @param interface [Y2Network::Interface]
    # @return [Boolean]
    def dhcp_candidate?(interface)
      Yast.include self, "network/routines.rb" # TODO: needed only for phy_connected

      return false if config.connections.by_name(interface.name)
      return false if ibft_interfaces.include?(interface.name)

      phy_connected?(interface.name)
    end

    def configure_dhcp
      Yast::Lan.Read(:cache)

      dhcp_cards = config.interfaces.select { |i| dhcp_candidate?(i) }

      log.info "Candidates for enabling DHCP: #{dhcp_cards.inspect}"
      return if dhcp_cards.empty?

      # TODO: time consuming, some progress would be nice
      dhcp_cards.each { |d| setup_dhcp(d) }

      activate_changes(dhcp_cards.map(&:name))

      # drop devices without dhcp lease
      inactive_devices = dhcp_cards.reject { |c| active_config?(c.name) }
      log.info "Inactive devices: #{inactive_devices}"

      inactive_devices.each { |c| delete_config(c) }

      # setup route flag
      active_devices = dhcp_cards - inactive_devices

      if active_devices.size == 1
        # just one dhcp device, nothing to care of
        set_default_route_flag(active_devices.first, "yes")
      else
        # try to find just one dhcp aware device for allowing default route
        # if there is more than one dhcp devices enabled for setting default
        # route (DHCLIENT_SET_DEFAULT_ROUTE = "yes"). bnc#868187
        active_devices.find { |d| set_default_route_flag_if_wan_dev?(d.name) }
      end

      activate_changes(dhcp_cards.map(&:name))

      # Force a read of the configuration just for reading the transient
      # hostname as it could be modified through dhcp since previous read.
      Lan.read_config(report: false)
    end

    # Decides if a proposal for virtualization host machine is required.
    #
    # @return [Boolean] whether the bridge network configuration for
    #   virtualization should be proposed or not
    def virtual_proposal_required?
      # S390 has special requirements. See bnc#817943
      return false if Arch.s390

      return true if Package.Installed("xen") && Arch.is_xen0
      return true if Package.Installed("kvm")
      return true if Package.Installed("qemu")

      false
    end

    # Propose configuration for virtual devices
    #
    # It checks if any of supported virtual machines were installed. If found,
    # propose virtual device(s) configuration
    def configure_virtuals
      return if !virtual_proposal_required?

      log.info("NetworkAutoconfiguration: proposing virtual devices")

      return unless Lan.ProposeVirtualized

      # avoid restarting network (installation can run via ssh, vnc, ...)
      # Moreover virtual devices are not needed during first stage. So, it can
      # wait for rebooting into just installed target
      return if Lan.yast_config == Lan.system_config

      Lan.write_config
    end

    # Propose DNS and Hostname setup
    def configure_dns
      DNS.Read # handles NetworkConfig too
      log.info("NetworkAutoconfiguration: proposing DNS / Hostname configuration")
      DNS.Write(netconfig_update: false)
    end

    # Proposes updates for /etc/hosts
    #
    # Expected to be used for updating target system's config.
    # Currently it only updates /etc/hosts with static IP if any.
    def configure_hosts
      Host.Read
      Host.ResolveHostnameToStaticIPs
      Host.Write
    end

    def configure_routing
      return if config.routing == Lan.system_config.routing

      Lan.write_config(only: [:routing])
    end

  private

    # Makes DHCP setup persistent
    #
    # instsys currently uses wicked as network services "manager" (including
    # dhcp client). wicked is currently able to configure a card for dhcp leases
    # only via loading config from file. All other ways are workarounds and
    # needn't to work when wickedd* services are already running
    # @param card [Y2Network::Interface]
    def setup_dhcp(card)
      builder = Y2Network::InterfaceConfigBuilder.for(card.type)
      builder.name = card.name

      builder.boot_protocol = Y2Network::BootProtocol::DHCP
      builder.startmode = Y2Network::Startmode.create("auto")

      builder.save
    end

    def delete_config(interface)
      config.delete_interface(interface.name)
    end

    # Writes and activates changes in devices configurations
    #
    # @param devnames [Array] list of device names
    # @return true when changes were successfully applied
    def activate_changes(devnames)
      Lan.write_config(only: [:connections])

      reload_config(devnames)
    end

    # Checks if given device is active
    #
    # active device <=> a device which is reported as "up" by wicked
    def active_config?(devname)
      wicked_query = "/usr/sbin/wicked ifstatus --brief #{devname.shellescape} |" \
        " /usr/bin/grep 'up$'"
      SCR.Execute(BASH_PATH, wicked_query).zero?
    end

    # Returns list of servers used for internet reachability test
    #
    # Basicaly servers with product release notes should be used.
    def target_servers
      ["scc.suse.com"]
    end

    # Check if given device can reach some of reference servers
    # rubocop:disable Naming/AccessorMethodName
    def set_default_route_flag_if_wan_dev?(devname)
      set_default_route_flag(devname, "yes")

      if !activate_changes([devname])
        log.warn("Cannot activate default_route for device #{devname}")
        return false
      end

      reached = target_servers.any? do |server|
        ping_cmd = "/usr/bin/ping -I #{devname.shellescape} -c 3 #{server.shellescape}"
        SCR.Execute(BASH_PATH, ping_cmd) == 0
      end

      log.info("Release notes can be reached via #{devname}: #{reached}")

      if !reached
        # bsc#900466: Device is currently used for default route, but the test
        # did not work, removing the default_route flag completely.
        log.info "Removing default_route flag for device #{devname}"
        set_default_route_flag(devname, nil)
        activate_changes([devname])
      end

      reached
    end
    # rubocop:enable Naming/AccessorMethodName

    # Sets sysconfig's DHCLIENT_SET_DEFAULT_ROUTE option for given device
    #
    # @param [String] devname name of device as seen by system (e.g. enp0s3)
    # @param [String] value "yes" or "no", as in sysconfig
    def set_default_route_flag(devname, value)
      # TODO: not implemented
    end

    def config
      Yast::Lan.yast_config
    end
  end
end
