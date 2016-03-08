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
# File:	modules/Routing.ycp
# Package:	Network configuration
# Summary:	Routing data (/etc/sysconfig/network/routes)
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# See routes(5)
# Does not work with interface-specific routes yet (ifroute-lo...)
require "yast"

module Yast
  class RoutingClass < Module
    # @return [Array<String>] names of devices with sysconfig configuration
    attr_reader :devices

    include Logger

    # @Orig_Routes [Array]        array of hashes. Caches known routes
    #
    # @Orig_Forward_v4 [Boolean]  current status of ipv4 forwarding
    # @Orig_Forward_v6 [Boolean]  current status of ipv6 forwarding
    #
    # @modified [Boolean]         modified by AY (bnc#649494)

    # "routes" and ifroute-DEV file directory
    ROUTES_DIR  = "/etc/sysconfig/network"
    # "routes" file location
    ROUTES_FILE = "/etc/sysconfig/network/routes"

    # sysctl keys, used as *single* SCR path components below
    IPV4_SYSCTL = "net.ipv4.ip_forward"
    IPV6_SYSCTL = "net.ipv6.conf.all.forwarding"
    # SCR paths
    SYSCTL_AGENT_PATH = ".etc.sysctl_conf"
    SYSCTL_IPV4_PATH = SYSCTL_AGENT_PATH + ".\"#{IPV4_SYSCTL}\""
    SYSCTL_IPV6_PATH = SYSCTL_AGENT_PATH + ".\"#{IPV6_SYSCTL}\""

    # see man routes - difference on implicit device param (aka "-") in
    # case of /etc/sysconfig/network/routes and /etc/sysconfig/network/
    # /ifroute-<device>
    ANY_DEVICE = "-"

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetHwDetection"
      Yast.import "NetworkInterfaces"
      Yast.import "Map"
      Yast.import "Mode"
      Yast.import "SuSEFirewall"
      Yast.import "FileUtils"

      Yast.include self, "network/runtime.rb"
      Yast.include self, "network/routines.rb"

      # All routes
      # list <map <string, string> >:
      # keys: destination, gateway, netmask, [device, [extrapara]]
      @Routes = []

      # Enable IP forwarding
      # .etc.sysctl_conf."net.ipv4.ip_forward"
      @Forward_v4 = false
      @Forward_v6 = false

      # List of available devices
      @devices = []
    end

    # Data was modified?
    # @return true if modified
    def Modified
      # probably called without Read()  (bnc#649494)
      no_orig_values = @Orig_Routes.nil?
      no_orig_values &&= @Orig_Forward_v4.nil?
      no_orig_values &&= @Orig_Forward_v6.nil?
      no_orig_values &&= @modified != true

      return false if no_orig_values

      ret = @Routes != @Orig_Routes
      ret ||= @Forward_v4 != @Orig_Forward_v4
      ret ||= @Forward_v6 != @Orig_Forward_v6

      Builtins.y2debug("Routing#modified: #{ret}")
      ret
    end

    # Set the routes to contain only the default route, if it is defined.
    # Used when there is nothing better.
    # @param [String] gw ip of the default gateway
    # @return true if success
    def ReadFromGateway(gw)
      return false if gw == "" || gw.nil?
      @Routes = [
        {
          "destination" => "default",
          "gateway"     => gw,
          "netmask"     => "-",
          "device"      => ANY_DEVICE
        }
      ]
      true
    end

    # Remove route with default gateway from Routes list
    def RemoveDefaultGw
      route = []
      Builtins.y2milestone(
        "Resetting default gateway - interface has been set to DHCP mode"
      )
      Builtins.foreach(@Routes) do |row|
        if Ops.get_string(row, "destination", "") != "default"
          route = Builtins.add(route, row)
        end
      end
      @Routes = deep_copy(route)

      nil
    end

    # Reads current status for both IPv4 and IPv6 forwarding
    def ReadIPForwarding
      if SuSEFirewall.IsEnabled
        @Forward_v4 = SuSEFirewall.GetSupportRoute
      else
        @Forward_v4 = SCR.Read(path(SYSCTL_IPV4_PATH)) == "1"
      end

      @Forward_v6 = SCR.Read(path(SYSCTL_IPV6_PATH)) == "1"

      log.info("Forward_v4=#{@Forward_v4}")
      log.info("Forward_v6=#{@Forward_v6}")

      nil
    end

    # Configures system for IPv4 forwarding
    #
    # @param [Boolean] true when forwarding should be enabled
    def write_ipv4_forwarding(forward_ipv4)
      sysctl_val = forward_ipv4 ? "1" : "0"

      if SuSEFirewall.IsEnabled
        SuSEFirewall.SetSupportRoute(forward_ipv4)
      else
        SCR.Write(
          path(SYSCTL_IPV4_PATH),
          sysctl_val
        )
        SCR.Write(path(SYSCTL_AGENT_PATH), nil)
      end

      SCR.Execute(path(".target.bash"), "sysctl -w #{IPV4_SYSCTL}=#{sysctl_val}")

      nil
    end

    # Configures system for IPv6 forwarding
    #
    # @param [Boolean] true when forwarding should be enabled
    def write_ipv6_forwarding(forward_ipv6)
      sysctl_val = forward_ipv6 ? "1" : "0"

      # SuSEfirewall2 has no direct support for IPv6 (aka FW_FORWARD).
      # Sysctl has to be configured manualy. bnc#916013
      SCR.Write(
        path(SYSCTL_IPV6_PATH),
        sysctl_val
      )
      SCR.Write(path(SYSCTL_AGENT_PATH), nil)

      SCR.Execute(path(".target.bash"), "sysctl -w #{IPV6_SYSCTL}=#{sysctl_val}")

      nil
    end

    # Configures system for both IPv4 and IPv6 forwarding
    def WriteIPForwarding
      write_ipv4_forwarding(@Forward_v4)
      write_ipv6_forwarding(@Forward_v6)
    end

    # Read routing settings
    # If no routes, sets a default gateway from Detection
    # @return true if success
    def Read
      # read available devices
      NetworkInterfaces.Read
      @devices = NetworkInterfaces.List("")

      # read routes
      @Routes = SCR.Read(path(".routes")) || []

      @devices.each do |device|
        # Mode.test required for old testsuite. Dynamic agent registration break
        # stubing there
        register_ifroute_agent_for_device(device) unless Mode.test

        dev_routes = SCR.Read(path(".ifroute-#{device}")) || []

        next if dev_routes.nil? || dev_routes.empty?

        dev_routes.map! do |route|
          route["device"] = device if route["device"] == ANY_DEVICE
          route
        end

        @Routes.concat dev_routes
      end

      @Routes.uniq!
      log.info("Routes=#{@Routes}")

      ReadIPForwarding()

      # save routes to check for changes later
      @Orig_Routes = deep_copy(@Routes)
      @Orig_Forward_v4 = @Forward_v4
      @Orig_Forward_v6 = @Forward_v6

      ReadFromGateway(NetHwDetection.result["GATEWAY"] || "") if @Routes.empty?

      @initialized = true

      true
    end

    # Write routing settings and apply changes
    # @return true if success
    def Write
      Builtins.y2milestone("Writing configuration")
      if !Modified()
        Builtins.y2milestone("No changes to routing -> nothing to write")
        return true
      end

      steps = [
        # Progress stage 1
        _("Write IP forwarding settings"),
        # Progress stage 2
        _("Write routing settings")
      ]

      caption = _("Saving Routing Configuration")

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      # Progress stage 1/2
      ProgressNextStage(_("Writing IP forwarding settings..."))

      WriteIPForwarding()

      # at first stop the running routes
      # FIXME: SCR::Execute(.target.bash, "/etc/init.d/route stop");
      # sysconfig does not support restarting routes only,
      # so we let our caller do it together with other things

      # Progress stage 2/2
      ProgressNextStage(_("Writing routing settings..."))

      ret = write_routes(@Routes)

      Progress.NextStage

      ret
    end

    # Clear file with routes definitions for particular device
    #
    # @param device is a device name (eth0) or special string Routes::ANY_DEVICE
    # @return [true, false] if succeedes
    def clear_route_file(device)
      # work around bnc#19476
      if device == ANY_DEVICE
        filename = ROUTES_FILE

        return SCR.Write(path(".target.string"), filename, "")
      else
        filename = "#{ROUTES_DIR}/ifroute-#{device}"

        return SCR.Execute(path(".target.remove"), filename) if FileUtils.Exists(filename)
        return true
      end
    end

    # From *routes*, select those belonging to *device* and write
    # an appropriate config file.
    # @param device device name, or "-" for global routes
    # @param routes [Array<Hash>] defines route; even unrelated to *device*
    # @return [true, false] if it succeedes
    def write_route_file(device, routes)
      routes = routes.select { |r| r["device"] == device }

      return clear_route_file(device) if routes.empty?

      if device == ANY_DEVICE
        scr_path = path(".routes")
      else
        scr_path = register_ifroute_agent_for_device(device)
      end

      SCR.Write(scr_path, routes)
    end

    # Updates routing configuration files
    #
    # It means /etc/sysconfig/network/routes and
    # /etc/sysconfig/network/ifroute-*
    #
    # @param routes [Array] of hashes which defines route
    # @return [true, false] if it succeedes
    def write_routes(routes)
      # create if not exists, otherwise backup
      if FileUtils.Exists(ROUTES_FILE)
        SCR.Execute(
          path(".target.bash"),
          "/bin/cp #{ROUTES_FILE} #{ROUTES_FILE}.YaST2save"
        )
      else
        SCR.Write(path(".target.string"), ROUTES_FILE, "")
      end

      ret = true

      # update the routes config
      Routing.devices.each do |device|
        written = write_route_file(device, routes)
        ret &&= written
      end

      written = write_route_file(ANY_DEVICE, routes)
      ret &&= written

      ret
    end

    # Get all the Routing configuration from a map.
    # When called by routing_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings autoinstallation settings
    # @return true if success
    def Import(settings)
      settings = deep_copy(settings)

      # Getting a list of devices which have already been imported by Lan.Import
      # (bnc#900352)
      @devices = NetworkInterfaces.List("")

      ip_forward = Ops.get_boolean(settings, "ip_forward", false)
      ipv4_forward = Ops.get_boolean(settings, "ipv4_forward", ip_forward)
      ipv6_forward = Ops.get_boolean(settings, "ipv6_forward", ip_forward)

      @Routes = deep_copy(Ops.get_list(settings, "routes", []))
      @Forward_v4 = ipv4_forward
      @Forward_v6 = ipv6_forward

      @Orig_Routes = nil
      @Orig_Forward_v4 = nil
      @Orig_Forward_v6 = nil

      @modified = true
      @initialized = true

      true
    end

    # Dump the Routing settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      exproute = {}

      # It should be case only for installer (1st stage). When routing
      # was configured via linuxrc, yast needn't to be aware of it. bnc#956012
      Read() if !@initialized

      log.info("Routing: exporting configuration #{@Routes}")

      exproute["routes"] = deep_copy(@Routes) unless @Routes.empty?
      exproute["ipv4_forward"] = @Forward_v4
      exproute["ipv6_forward"] = @Forward_v6

      exproute
    end

    # Get the current devices list
    # @return devices list
    def GetDevices
      deep_copy(@devices)
    end

    # Get the default gateway
    # @return gateway
    def GetGateway
      defgw = ""
      Builtins.maplist(@Routes) do |r|
        if Ops.get_string(r, "destination", "") == "default"
          defgw = Ops.get_string(r, "gateway", "")
        end
      end
      defgw
    end

    # Set the available devices list (for expert routing dialog)
    # @param [Array] devs new devices list
    # @return true if success
    def SetDevices(devs)
      devs = deep_copy(devs)
      if devs.nil?
        @devices = []
        return false
      end
      @devices = deep_copy(devs)
      true
    end

    # Create routing text summary
    # @returns [String] summary text
    def Summary
      return "" if @Routes.nil? || @Routes.empty?

      Yast.import "Summary"
      summary = ""

      gw = GetGateway()
      gwhost = NetHwDetection.ResolveIP(gw)
      gw = "#{gw} (#{gwhost})" unless gwhost.empty?

      # Summary text
      summary = Summary.AddListItem(summary, _("Gateway: %s") % gw) unless gw.empty?

      on_off = @Forward_v4 ? "on" : "off"
      # Summary text
      summary = Summary.AddListItem(summary, _("IP Forwarding for IPv4: %s") % on_off)

      on_off = @Forward_v6 ? "on" : "off"
      # Summary text
      summary = Summary.AddListItem(summary, _("IP Forwarding for IPv6: %s") % on_off)

      return "" if summary.empty?

      "<ul>#{summary}</ul>"
    end

    publish variable: :Routes, type: "list <map>"
    publish variable: :Forward_v4, type: "boolean"
    publish variable: :Forward_v6, type: "boolean"
    publish function: :Modified, type: "boolean ()"
    publish function: :ReadFromGateway, type: "boolean (string)"
    publish function: :RemoveDefaultGw, type: "void ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :GetDevices, type: "list ()"
    publish function: :GetGateway, type: "string ()"
    publish function: :SetDevices, type: "boolean (list)"
    publish function: :Summary, type: "string ()"

  private

    def ifroute_term(device)
      raise ArgumentError if device.nil? || device.empty?

      non_empty_str_term = term(:String, "^ \t\n")
      whitespace_term = term(:Whitespace)
      optional_whitespace_term = term(:Optional, whitespace_term)
      routes_content_term = term(
        :List,
        term(
          :Tuple,
          term(
            :destination,
            non_empty_str_term
          ),
          whitespace_term,
          term(:gateway, non_empty_str_term),
          whitespace_term,
          term(:netmask, non_empty_str_term),
          optional_whitespace_term,
          term(
            :Optional,
            term(:device, non_empty_str_term)
          ),
          optional_whitespace_term,
          term(
            :Optional,
            term(
              :extrapara,
              term(:String, "^\n")
            )
          )
        ),
        "\n"
      )

      term(
        :ag_anyagent,
        term(
          :Description,
          term(:File, "#{ROUTES_DIR}/ifroute-#{device}"),
          "#\n",
          false,
          routes_content_term
        )
      )
    end

    # Registers SCR agent which is used for accessing particular ifroute-device
    # file
    #
    # @param device [String] device name (e.g. eth0, enp0s3, ...)
    # @return [Path] SCR path of the agent
    # @raise  [RuntimeError] if it fails
    def register_ifroute_agent_for_device(device)
      scr_path = path(".ifroute-#{device}")
      SCR.RegisterAgent(scr_path, ifroute_term(device)) ||
        raise("Cannot SCR.RegisterAgent(#{scr_path}, ...)")
      scr_path
    end
  end

  Routing = RoutingClass.new
  Routing.main
end
