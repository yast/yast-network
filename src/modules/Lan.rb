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
# File:  modules/Lan.ycp
# Package:  Network configuration
# Summary:  Network card data
# Authors:  Michal Svec <msvec@suse.cz>
#
#
# Representation of the configuration of network cards.
# Input and output routines.
require "yast"
require "cfa/sysctl_config"
require "network/network_autoyast"
require "network/confirm_virt_proposal"
require "ui/text_helpers"
require "y2firewall/firewalld"
require "y2network/autoinst_profile/networking_section"
require "y2network/autoinst/config"
require "y2network/config"
require "y2network/virtualization_config"
require "y2network/interface_config_builder"
require "y2network/presenters/summary"

require "shellwords"

module Yast
  class LanClass < Module
    include ::UI::TextHelpers
    include Wicked

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Arch"
      Yast.import "NetHwDetection"
      Yast.import "Host"
      Yast.import "IP"
      Yast.import "Map"
      Yast.import "Mode"
      Yast.import "NetworkConfig"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Package"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "String"
      Yast.import "FileUtils"
      Yast.import "PackageSystem"
      Yast.import "LanItems"
      Yast.import "ModuleLoading"
      Yast.import "Linuxrc"

      Yast.include self, "network/complex.rb"
      Yast.include self, "network/runtime.rb"

      #-------------
      # GLOBAL DATA

      # gui or cli mode
      @gui = true

      @write_only = false

      # ipv6 module
      @ipv6 = true

      # Hotplug type ("" if not hot pluggable)

      # Abort function
      # return boolean return true if abort
      @AbortFunction = nil

      # list of interface names which were recently assigned as a slave to a bond device
      @bond_autoconf_slaves = []

      # list of interface names which were recently enslaved in a bridge or bond device
      @autoconf_slaves = []

      # Lan::Read (`cache) will do nothing if initialized already.
      @initialized = false

      @backend = nil

      @modified = false

      # Y2Network::Config objects
      @configs = {}
    end

    # @return [Boolean]
    attr_accessor :write_only
    # @return [Autoinst::Config]
    attr_writer :autoinst

    #------------------
    # GLOBAL FUNCTIONS
    #------------------

    # Return a modification status
    # @return true if data was modified
    def Modified
      return true if @modified
      return true unless system_config == yast_config
      return true if NetworkConfig.Modified
      return true if NetworkService.Modified
      return true if Host.GetModified

      false
    end

    def SetModified
      @modified = true
      nil
    end

    # function for use from autoinstallation (Fate #301032)
    def isAnyInterfaceDown
      down = false
      link_status = devices_link_status

      log.info("link_status #{link_status}")
      configurations = (Yast::Lan.system_config&.interfaces&.map(&:name) || [])
      configurations.each do |devname|
        address_file = "/sys/class/net/#{devname}/address"
        mac = ::File.read(address_file).chomp if ::File.file?(address_file)
        log.info("confname #{mac}")
        if !link_status.keys.include?(mac)
          log.error("Mac address #{mac} not found in map #{link_status}!")
        elsif link_status[mac] == false
          log.warn("Interface with mac #{mac} is down!")
          down = true
        else
          log.debug("Interface with mac #{mac} is up")
        end
      end
      down
    end

    # Checks local configuration if IPv6 is allowed
    #
    # return [Boolean] true when IPv6 is enabled in the system
    def readIPv6
      sysctl_config_file = CFA::SysctlConfig.new
      sysctl_config_file.load
      ipv6 = !sysctl_config_file.disable_ipv6
      log.info("readIPv6: IPv6 is #{ipv6 ? "enabled" : "disabled"}")
      ipv6
    end

    def read_step_labels
      steps = [
        # Progress stage 1/7
        _("Detect network devices"),
        # Progress stage 2/7
        _("Read driver information"),
        # Progress stage 3/7
        _("Detect current status"),
        # Progress stage 4/7 - multiple devices may be present, really plural
        _("Read device configuration"),
        # Progress stage 5/7
        _("Read network configuration"),
        # Progress stage 6/7
        _("Read installation information"),
        # Progress stage 7/7
        _("Read routing configuration")

      ]

      steps << _("Read firewall configuration") if firewalld.installed?
      steps
    end

    # Read all network settings from the SCR
    # @param cache [Symbol] :cache=use cached data, :nocache=reread from disk
    #  TODO: pass to submodules
    # @return true on success
    def Read(cache)
      if cache == :cache && @initialized
        Builtins.y2milestone("Using cached data")
        return true
      end

      # Read dialog caption
      caption = _("Initializing Network Configuration")

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      if @gui
        Progress.New(
          caption,
          " ",
          read_step_labels.size,
          read_step_labels,
          [],
          ""
        )
      end

      return false if Abort()

      ProgressNextStage(_("Detecting ndiswrapper...")) if @gui
      # modprobe ndiswrapper before hwinfo when needed (#343893)
      if !Mode.autoinst && PackageSystem.Installed("ndiswrapper")
        Builtins.y2milestone("ndiswrapper: installed")
        if Ops.greater_than(
          Builtins.size(
            Convert.convert(
              SCR.Read(path(".target.dir"), "/etc/ndiswrapper"),
              from: "any",
              to:   "list <string>"
            )
          ),
          0
        )
          Builtins.y2milestone("ndiswrapper: configuration found")
          if Convert.to_integer(
            SCR.Execute(path(".target.bash"), "/usr/sbin/lsmod | /usr/bin/grep -q ndiswrapper")
          ) != 0 &&
              Popup.YesNo(
                _(
                  "Detected a ndiswrapper configuration,\n" \
                    "but the kernel module was not modprobed.\n" \
                    "Do you want to modprobe ndiswrapper?\n"
                )
              )
            if ModuleLoading.Load("ndiswrapper", "", "", "", false, true) == :fail
              Popup.Error(
                _(
                  "ndiswrapper kernel module has not been loaded.\nCheck configuration manually.\n"
                )
              )
            end
          end
        end
      end

      Builtins.sleep(sl)

      return false if Abort()

      ProgressNextStage(_("Detecting network devices...")) if @gui
      # Dont read hardware data in config mode
      NetHwDetection.Start if !Mode.config

      Builtins.sleep(sl)

      return false if Abort()

      begin
        ProgressNextStage(_("Detecting current status...")) if @gui
        NetworkService.Read
        Builtins.sleep(sl)

        return false if Abort()

        ProgressNextStage(_("Reading device configuration...")) if @gui
        read_config

        Builtins.sleep(sl)

        return false if Abort()

        ProgressNextStage(_("Reading network configuration...")) if @gui
        NetworkConfig.Read

        @ipv6 = readIPv6

        Builtins.sleep(sl)

        Host.Read
        Builtins.sleep(sl)

        return false if Abort()

        if firewalld.installed? && !firewalld.read?
          ProgressNextStage(_("Reading firewall configuration...")) if @gui
          firewalld.read
          Builtins.sleep(sl)
        end

        return false if Abort()
      rescue IOError, SystemCallError, RuntimeError => e
        msg = format(_("Network configuration is corrupted.\n"\
                "If you continue resulting configuration can be malformed."\
                "\n\n%s"), wrap_text(e.message))
        return false if !@gui
        return false if !Popup.ContinueCancel(msg)
      end

      # Final progress step
      ProgressNextStage(_("Finished")) if @gui
      Builtins.sleep(sl)

      return false if Abort()

      @initialized = true

      fix_dhclient_warning(LanItems.invalid_dhcp_cfgs) if @gui && !LanItems.valid_dhcp_cfg?

      Progress.Finish if @gui

      true
    end

    # (a specialization used when a parameterless function is needed)
    # @return [Boolean] true on success
    def ReadWithCache
      Read(:cache)
    end

    def ReadWithCacheNoGUI
      @gui = false
      ReadWithCache()
    end

    def SetIPv6(status)
      if @ipv6 != status
        @ipv6 = status
        Popup.Warning(_("To apply this change, a reboot is needed."))
        Lan.SetModified
      end

      nil
    end

    def writeIPv6
      log.info("writeIPv6: IPv6 is #{@ipv6 ? "enabled" : "disabled"}")
      sysctl_config_file = CFA::SysctlConfig.new
      sysctl_config_file.load
      sysctl_config_file.disable_ipv6 = !@ipv6
      sysctl_config_file.save unless sysctl_config_file.conflict?
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "/usr/sbin/sysctl -w net.ipv6.conf.all.disable_ipv6=%1",
          @ipv6 ? "0" : "1"
        )
      )
      SCR.Write(
        path(".sysconfig.windowmanager.KDE_USE_IPV6"),
        @ipv6 ? "yes" : "no"
      )

      nil
    end

    # Update the SCR according to network settings
    # @return true on success
    def Write(gui: true, apply_config: !write_only)
      log.info("Writing configuration")

      # Query modified flag in all components, not just LanItems - DNS,
      # Routing, NetworkConfig too in order not to discard changes made
      # outside LanItems (bnc#439235)
      if !Modified()
        log.info("No changes to network setup -> nothing to write")
        return true
      end

      # Write dialog caption
      caption = _("Saving Network Configuration")

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      step_labels = [
        # Progress stage 2
        _("Write drivers information"),
        # Progress stage 3 - multiple devices may be present,really plural
        _("Write device configuration"),
        # Progress stage 4
        _("Write network configuration"),
        # Progress stage 5
        _("Write routing configuration"),
        # Progress stage 6
        _("Write hostname and DNS configuration"),
        # Progress stage 7
        _("Set up network services")
      ]

      # Progress stage 8
      step_labels << _("Writing firewall configuration") if firewalld.installed?

      # Progress stage 9
      step_labels = Builtins.add(step_labels, _("Activate network services")) if apply_config
      # Progress stage 10
      step_labels = Builtins.add(step_labels, _("Update configuration"))

      Progress.New(
        caption,
        " ",
        Builtins.size(step_labels),
        step_labels,
        [],
        ""
      )

      return false if Abort()

      # Progress step 2
      ProgressNextStage(_("Writing /etc/modprobe.conf..."))
      Builtins.sleep(sl)

      return false if Abort()

      # Progress step 3 - multiple devices may be present, really plural
      ProgressNextStage(_("Writing device configuration..."))
      Builtins.sleep(sl)

      return false if Abort()

      # Progress step 4
      ProgressNextStage(_("Writing network configuration..."))
      NetworkConfig.Write
      Builtins.sleep(sl)

      return false if Abort()

      # Progress step 5
      ProgressNextStage(_("Writing routing configuration..."))
      orig = Progress.set(false)

      write_config

      Progress.set(orig)
      Builtins.sleep(sl)

      return false if Abort()

      # Progress step 6
      ProgressNextStage(_("Writing hostname and DNS configuration..."))
      # write resolv.conf after change from dhcp to static (#327074)
      # reload/restart network before this to put correct resolv.conf from dhcp-backup
      orig = Progress.set(false)
      Host.Write(gui: gui)
      Progress.set(orig)

      Builtins.sleep(sl)

      return false if Abort()

      # Progress step 7
      ProgressNextStage(_("Setting up network services..."))
      writeIPv6
      Builtins.sleep(sl)

      if firewalld.installed?
        return false if Abort()

        # Progress step 7
        ProgressNextStage(_("Writing firewall configuration..."))
        firewalld.write
        Builtins.sleep(sl)
      end

      if apply_config
        return false if Abort()

        # Progress step 9
        ProgressNextStage(_("Activating network services..."))

        select_network_service ? activate_network_service : NetworkService.disable

        Builtins.sleep(sl)
      end

      return false if Abort()

      # Progress step 10
      ProgressNextStage(_("Updating configuration..."))
      update_mta_config if !apply_config
      Builtins.sleep(sl)

      ensure_network_running if yast_config.backend?(:network_manager)

      # Final progress step
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      Progress.Finish

      return false if Abort()

      true
    end

    # Only write configuration without starting any init scripts and SuSEconfig
    # @return true on success
    def WriteOnly
      @write_only = !autoinst.start_immediately
      Write()
    end

    def autoinst
      @autoinst ||= Y2Network::Autoinst::Config.new
    end

    # If there's key in modify, upcase key and assign the value to ret
    # @return ret
    def UpcaseCondSet(ret, modify, key)
      ret = deep_copy(ret)
      modify = deep_copy(modify)
      Ops.set(ret, Builtins.toupper(key), Ops.get(modify, key)) if Builtins.haskey(modify, key)
      deep_copy(ret)
    end

    # Convert data from autoyast to structure used by module.
    # @param [Hash] input autoyast settings
    # @return [Hash] native network settings
    # FIXME: massive refactoring required
    def FromAY(input)
      input = deep_copy(input)
      Builtins.y2debug("input %1", input)

      input["interfaces"] ||= []
      # DHCP:: config: some of it is in the DNS part of the profile
      dhcp = {}
      dhcpopts = Ops.get_map(input, "dhcp_options", {})
      dns = Ops.get_map(input, "dns", {})

      if Builtins.haskey(dns, "dhcp_hostname")
        Ops.set(
          dhcp,
          "DHCLIENT_SET_HOSTNAME",
          Ops.get_boolean(dns, "dhcp_hostname", false)
        )
      end

      dhcp = UpcaseCondSet(dhcp, dhcpopts, "dhclient_client_id")
      dhcp = UpcaseCondSet(dhcp, dhcpopts, "dhclient_additional_options")
      dhcp = UpcaseCondSet(dhcp, dhcpopts, "dhclient_hostname_option")

      Ops.set(input, "config", "dhcp" => dhcp)
      if !Ops.get(input, "strict_IP_check_timeout").nil?
        input["strict_ip_check_timeout"] = input.delete("strict_IP_check_timeout")
        Ops.set(input, ["config", "config"], "CHECK_DUPLICATE_IP" => true)
      end

      Builtins.y2milestone("input=%1", input)
      input
    end

    # Import data.
    # It expects data described networking.rnc
    # and then passed through {#FromAY}.
    # Most prominently, instead of a flat list called "interfaces"
    # we import a 2-level map of typed "devices"
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = {} if settings.nil?

      Read(:cache)
      profile = Y2Network::AutoinstProfile::NetworkingSection.new_from_hashes(settings)
      config = Y2Network::Config.from(:autoinst, profile, system_config)
      add_config(:yast, config)
      @autoinst = autoinst_config(profile)
      if Arch.s390
        NetworkAutoYast.instance.activate_s390_devices(settings.fetch("s390-devices", {}))
      end

      NetworkConfig.Import(settings["config"] || {})
      # Ensure that the /etc/hosts has been read to no blank out it in case of
      # not defined <host> section (bsc#1058396)
      Host.Read

      @ipv6 = settings.fetch("ipv6", true)

      true
    end

    # Export data.
    # They need to be converted to become what networking.rnc describes.
    # @see Y2Network::Clients::Auto.adapt_for_autoyast
    #
    # Most prominently, instead of a flat list called "interfaces"
    # we export a 2-level map of typed "devices"
    # @return dumped settings
    def Export
      profile = Y2Network::AutoinstProfile::NetworkingSection.new_from_network(yast_config)
      ay = profile.to_hashes
      ay["ipv6"] = @ipv6
      ay["config"] = NetworkConfig.Export unless ay["managed"]

      log.info("Exported map: #{ay}")
      deep_copy(ay)
    end

    # Create a textual summary and a list of unconfigured devices
    # @param [String] mode "summary": add resolver and routing summary,
    #   "proposal": for proposal also with resolver an routing summary
    # @return summary of the current configuration
    def Summary(mode)
      case mode
      when "summary", "proposal"
        Y2Network::Presenters::Summary.text_for(yast_config, mode)
      else
        Y2Network::Presenters::Summary.text_for(yast_config, "interfaces")
      end
    end

    # Uses product info and is subject to installed packages.
    # @return Should NM be enabled?
    def UseNetworkManager
      nm_default = false
      nm_feature = ProductFeatures.GetStringFeature(
        "network",
        "network_manager"
      )

      case nm_feature
      when ""
        # compatibility: use the boolean feature
        # (defaults to false)
        nm_default = ProductFeatures.GetBooleanFeature(
          "network",
          "network_manager_is_default"
        )
      when "always"
        nm_default = true
      when "laptop"
        nm_default = Arch.is_laptop
        log.info("Is a laptop: #{nm_default}")
      end

      nm_installed = Package.Installed("NetworkManager")
      log.info("NetworkManager wanted: #{nm_default}, installed: #{nm_installed}")

      nm_default && nm_installed
    end

    def ProposeVirtualized
      Y2Network::VirtualizationConfig.new(yast_config).create
    end

    # Proposes additional packages when needed by current networking setup
    #
    # @return [Array] of packages needed when writing the config
    def Packages
      pkgs = []

      if yast_config&.backend?(:network_manager)
        pkgs << "NetworkManager" if !PackageSystem.Installed("NetworkManager")
      elsif !PackageSystem.Installed("wpa_supplicant")
        # we have to add wpa_supplicant when wlan is in game, wicked relies on it
        pkgs << "wpa_supplicant" if !LanItems.find_type_ifaces("wlan").empty?
      end

      pkgs.uniq!

      log.info("Additional packages requested by yast2-network: #{pkgs.inspect}") if !pkgs.empty?

      pkgs
    end

    # @return [Array] of packages needed when writing the config in autoinst
    # mode
    def AutoPackages
      { "install" => Packages(), "remove" => [] }
    end

    # Xen bridging confuses us (#178848)
    # @return whether xenbr* exists
    def HaveXenBridge
      # adapted test for xen bridged network (bnc#553794)
      have_br = FileUtils.Exists("/dev/.sysconfig/network/xenbridges")
      Builtins.y2milestone("Have Xen bridge: %1", have_br)
      have_br
    end

    # Provides a list with the NTP servers obtained via any of dhcp aware
    # interfaces
    #
    # @note parsing dhcp ntp servers when NetworkManager is in use is not
    #   supported yet (bsc#798886)
    #
    # @return [Array<String>] list of ntp servers obtained byg DHCP
    def dhcp_ntp_servers
      # Used before the config has been read
      return [] if !NetworkService.isNetworkRunning || Yast::NetworkService.is_network_manager

      ReadWithCacheNoGUI()
      Yast::LanItems.dhcp_ntp_servers.values.flatten.uniq
    end

    # Returns the network configuration with the given ID
    #
    # @param id [Symbol] Network configuration ID
    # @return [Y2Network::Config,nil] Network configuration with the given ID or nil if not found
    def find_config(id)
      Y2Network::Config.find(id)
    end

    # Adds the configuration
    #
    # @param id     [Symbol] Configuration ID
    # @param config [Y2Network::Config] Network configuration
    def add_config(id, config)
      Y2Network::Config.add(id, config)
    end

    # Clears the network configurations list
    def clear_configs
      Y2Network::Config.reset
    end

    # Returns the system configuration
    #
    # Just a convenience method.
    #
    # @return [Y2Network::Config]
    def system_config
      find_config(:system)
    end

    # Returns YaST configuration
    #
    # Just a convenience method.
    #
    # @return [Y2Network::Config]
    def yast_config
      find_config(:yast)
    end

    # Reads system configuration
    #
    # It clears already read configuration.
    def read_config
      system_config = Y2Network::Config.from(:sysconfig)
      system_config.backend = NetworkService.cached_name
      Yast::Lan.add_config(:system, system_config)
      Yast::Lan.add_config(:yast, system_config.copy)
    end

    # Writes current yast config and replace the system config with it
    def write_config
      target = :sysconfig if Mode.auto
      yast_config.write(original: system_config, target: target)
      # Force a refresh of the system_config bsc#1162987
      add_config(:system, yast_config.copy)
    end

    publish variable: :ipv6, type: "boolean"
    publish variable: :AbortFunction, type: "block <boolean>"
    publish variable: :bond_autoconf_slaves, type: "list <string>"
    publish variable: :autoconf_slaves, type: "list <string>"
    publish function: :Modified, type: "boolean ()"
    publish function: :isAnyInterfaceDown, type: "boolean ()"
    publish function: :Read, type: "boolean (symbol)"
    publish function: :ReadWithCache, type: "boolean ()"
    publish function: :ReadWithCacheNoGUI, type: "boolean ()"
    publish function: :SetIPv6, type: "void (boolean)"
    publish function: :Write, type: "boolean ()"
    publish function: :WriteOnly, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :Summary, type: "list (string)"
    publish function: :Add, type: "boolean ()"
    publish function: :Delete, type: "boolean ()"
    publish function: :AnyDHCPDevice, type: "boolean ()"
    publish function: :Packages, type: "list <string> ()"
    publish function: :AutoPackages, type: "map ()"
    publish function: :HaveXenBridge, type: "boolean ()"

    NM_DHCP_TIMEOUT = 45

  private

    def ensure_network_running
      network = false
      timeout = NM_DHCP_TIMEOUT
      while timeout > 0
        if NetworkService.isNetworkRunning
          network = true
          break
        end
        log.info("waiting for network ... #{timeout}")
        sleep(1)
        timeout -= 1
      end

      Popup.Error(_("No network running")) unless network
    end

    # @return [Array<Y2Network::Config>]
    attr_reader :configs

    def autoinst_config(section)
      return unless autoinst_settings?(section)

      Y2Network::Autoinst::Config.new(
        before_proposal:      section.setup_before_proposal,
        start_immediately:    section.start_immediately,
        keep_install_network: section.keep_install_network,
        ip_check_timeout:     section.strict_ip_check_timeout
      )
    end

    def autoinst_settings?(section)
      return false unless section

      !section.start_immediately.nil? ||
        !section.keep_install_network.nil? ||
        !section.setup_before_proposal.nil?
    end

    def activate_network_service
      # If the second installation stage has been called by yast.ssh via
      # ssh, we should not restart network because systemctl
      # hangs in that case. (bnc#885640)
      action = :reload_restart   if Stage.normal || !Linuxrc.usessh
      action = :remote_installer if Stage.initial && (Linuxrc.usessh || Linuxrc.vnc)

      case action
      when :reload_restart
        log.info("Attempting to reload network service, normal stage #{Stage.normal}, " \
          "ssh: #{Linuxrc.usessh}")

        NetworkService.ReloadOrRestart if Stage.normal || !Linuxrc.usessh
      when :remote_installer
        connection_names = yast_config&.connections&.map(&:name) || []

        # last instance handling "special" cases like ssh installation
        # FIXME: most probably not everything will be set properly
        log.info("Running in ssh/vnc installer -> just setting links up")
        log.info("Configured connections: #{connection_names}")

        reload_config(connection_names)
      end
    end

    def select_network_service
      NetworkService.use(yast_config&.backend&.id)
    end

    def firewalld
      Y2Firewall::Firewalld.instance
    end

    # Obtains the list of the system network devices names through the sysfs
    #
    # @return [Array<String>] names of the system network devices
    def devices_from_sys
      interfaces = Yast::Execute.stdout.on_target!("/usr/bin/ls", "/sys/class/net").split("\n")
      interfaces.delete("lo")
      interfaces
    end

    # Returns the mac address and whether the device has an ip associated or
    # not of the given interface name
    #
    # @return [Array(2)<String, Boolean>] mac address and ip assignation status
    def link_status(name)
      addr_show = ["/usr/sbin/ip", "address", "show", name]
      inet_link = ["grep", "inet\\|link"]
      row = Yast::Execute.stdout.on_target!(addr_show, inet_link).split("\n").map(&:strip)
      addr = false
      tmp_mac = nil
      row.each do |column|
        tmp_col = column.split(" ")
        next if tmp_col.size < 2

        tmp_mac = tmp_col[1] if tmp_col[0] == "link/ether"
        addr = true if tmp_col[0] == "inet"
      end

      [tmp_mac, addr]
    end

    # Convenience method to obtain the mac and ip assignment status of the
    # system network devices
    def devices_link_status
      devices_from_sys.each_with_object({}) do |name, hash|
        tmp_mac, addr = link_status(name)
        hash[tmp_mac] ||= addr if tmp_mac
        log.debug("link_status #{hash.inspect}")
      end
    end
  end

  Lan = LanClass.new
  Lan.main
end
