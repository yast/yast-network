# encoding: utf-8

require "yast"

module Yast
  # The class is responsible for generating / proposing automatic
  # configuration during installation workflow
  class NetworkAutoconfiguration
    include Singleton
    include Logger
    include Yast

    Yast.import "Lan"
    Yast.import "LanItems"
    Yast.import "NetworkInterfaces"
    Yast.import "Package"
    Yast.import "DNS"
    Yast.import "Arch"
    Yast.import "Host"

    BASH_PATH = Path.new(".target.bash")

    def configure_dhcp
      Yast.include self, "network/routines.rb"

      # find out network devices suitable for dhcp autoconfiguration.
      # Such device has to:
      # - be unconfigured
      # - physically connected to a network
      #   (it speeds up the initialization phase of installer - bnc#872319)
      dhcp_cards = network_cards.select do |c|
        !configured?(c) && phy_connected?(c)
      end
      log.info "Candidates for enabling DHCP: #{dhcp_cards}"

      # TODO: time consuming, some progress would be nice
      dhcp_cards.each { |d| setup_dhcp(d) }

      activate_changes(dhcp_cards)

      # drop devices without dhcp lease
      inactive_devices = dhcp_cards.select { |c| !active_config?(c) }
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
        active_devices.find { |d| set_default_route_flag_if_wan_dev?(d) }
      end

      activate_changes(dhcp_cards)
    end

    # Propose configuration for virtual devices
    #
    # It checks if any of supported virtual machines were installed. If found,
    # propose virtual device(s) configuration
    def configure_virtuals
      return if !virtual_proposal_required?

      log.info("NetworkAutoconfiguration: proposing virtual devices")

      Lan.ProposeVirtualized

      # avoid restarting network (installation can run via ssh, vnc, ...)
      # Moreover virtual devices are not needed during first stage. So, it can
      # wait for rebooting into just installed target
      Lan.WriteOnly
    end

    # Propose DNS and Hostname setup
    def configure_dns
      DNS.Read # handles NetworkConfig too
      DNS.ProposeHostname # generate random hostname, if none known so far

      # FIXME: after SLE12: DNS.default_dhcp_hostname should be private (setting
      # default values is not something for an API), but that would need some
      # refactoring of this part.
      DNS.dhcp_hostname = DNS.default_dhcp_hostname

      # get default value, from control.xml
      DNS.write_hostname = DNS.DefaultWriteHostname

      log.info("NetworkAutoconfiguration: proposing DNS / Hostname configuration")
      log.info("dhcp hostname: #{DNS.dhcp_hostname}")
      log.info("write hostname: #{DNS.write_hostname}")

      DNS.Write
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

  private

    def network_cards
      LanItems.Read
      LanItems.GetNetcardNames
    end

    # Makes DHCP setup persistent
    #
    # instsys currently uses wicked as network services "manager" (including
    # dhcp client). wicked is currently able to configure a card for dhcp leases
    # only via loading config from file. All other ways are workarounds and
    # needn't to work when wickedd* services are already running
    def setup_dhcp(card)
      index = LanItems.FindDeviceIndex(card)

      raise "Failed to save configuration for device #{card}" if index == -1

      LanItems.current = index
      LanItems.SetItem

      # tricky part if ifcfg is not set
      # yes, this code smell and show bad API of LanItems
      if !LanItems.IsCurrentConfigured
        NetworkInterfaces.Add
        current = LanItems.Items[LanItems.current]
        current["ifcfg"] = card
      end

      LanItems.bootproto = "dhcp"
      LanItems.startmode = "auto"

      LanItems.Commit
    end

    # Reloads configuration for each device named in devs
    #
    # @devs [Array] list of device names
    # @return true if configuration was reloaded
    def reload_config(devs)
      raise ArgumentError if devs.nil?
      return true if devs.empty?

      SCR.Execute(BASH_PATH, "wicked ifreload #{devs.join(" ")}") == 0
    end

    def delete_config(devname)
      LanItems.delete_dev(devname)
    end

    def write_configuration
      NetworkInterfaces.Write("")
    end

    # Writes and activates changes in devices configurations
    #
    # @devnames [Array] list of device names
    # @return true when changes were successfully applied
    def activate_changes(devnames)
      return false if !write_configuration

      # workaround for gh#yast/yast-core#74 (https://github.com/yast/yast-core/issues/74)
      NetworkInterfaces.CleanCacheRead()

      reload_config(devnames)
    end

    def configured?(devname)
      # TODO: one day there should be LanItems.IsItemConfigured, but we currently
      # miss index -> devname translation. As this LanItems internal structure
      # will be subject of refactoring, we will use NetworkInterfaces directly.
      # It currently doesn't hurt as it currently writes configuration for both
      # wicked even sysconfig.
      NetworkInterfaces.Check(devname)
    end

    # Checks if given device is active
    #
    # active device <=> a device which is reported as "up" by wicked
    def active_config?(devname)
      wicked_query = "wicked ifstatus --brief #{devname} | grep 'up$'"
      SCR.Execute(BASH_PATH, wicked_query) == 0
    end

    # Returns list of servers used for internet reachability test
    #
    # Basicaly servers with product release notes should be used.
    def target_servers
      ["scc.suse.com"]
    end

    # Check if given device can reach some of reference servers
    def set_default_route_flag_if_wan_dev?(devname)
      set_default_route_flag(devname, "yes")

      if !activate_changes([devname])
        log.warn("Cannot activate default_route for device #{devname}")
        return false
      end

      reached = target_servers.any? do |server|
        ping_cmd = "ping -I #{devname} -c 3 #{server}"
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

    # Sets sysconfig's DHCLIENT_SET_DEFAULT_ROUTE option for given device
    #
    # @param [String] devname name of device as seen by system (e.g. enp0s3)
    # @param [String] value "yes" or "no", as in sysconfig
    def set_default_route_flag(devname, value)
      item_id = LanItems.FindDeviceIndex(devname)
      LanItems.SetItemSysconfigOpt(item_id, "DHCLIENT_SET_DEFAULT_ROUTE", value)
    end

    # Decides if a proposal for virtualization host machine is required.
    def virtual_proposal_required?
      # S390 has special requirements. See bnc#817943
      return false if Arch.s390

      return true if PackageSystem.Installed("xen") && !Arch.is_xenU
      return true if PackageSystem.Installed("kvm")
      return true if PackageSystem.Installed("qemu")

      false
    end
  end
end
