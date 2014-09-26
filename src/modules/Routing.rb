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
    # @!attribute [r] devices
    # @return [Array<String>] names of devices with sysconfig configuration
    attr_reader :devices

    include Logger

    # @Orig_Routes [Array]        array of hashes. Caches known routes
    #
    # @Orig_Forward_v4 [Boolean]  current status of ipv4 forwarding
    # @Orig_Forward_v6 [Boolean]  current status of ipv6 forwarding
    #
    # @modified [Boolean]         modified by AY (bnc#649494)

    # "routes" file location
    ROUTES_FILE = "/etc/sysconfig/network/routes"

    SYSCTL_IPV4_PATH = ".etc.sysctl_conf.\"net.ipv4.ip_forward\""
    SYSCTL_IPV6_PATH = ".etc.sysctl_conf.\"net.ipv6.conf.all.forwarding\""

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
      return false if gw == "" || gw == nil
      @Routes = [
        {
          "destination" => "default",
          "gateway"     => gw,
          "netmask"     => "-",
          "device"      => "-"
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

    def ReadIPForwarding
      if SuSEFirewall.IsEnabled
        @Forward_v4 = SuSEFirewall.GetSupportRoute
        # FIXME: missing support for setting IPv6 forwarding enablement in 
        # SuSEFirewall module and in SuSEFirewall2 at all
      else
        @Forward_v4 = SCR.Read(path(SYSCTL_IPV4_PATH)) == "1"
        @Forward_v6 = SCR.Read(path(SYSCTL_IPV6_PATH)) == "1"
      end

      log.info("Forward_v4=#{@Forward_v4}")
      log.info("Forward_v6=#{@Forward_v6}")

      nil
    end

    def WriteIPForwarding
      forward_ipv4 = @Forward_v4 ? "1" : "0"
      forward_ipv6 = @Forward_v6 ? "1" : "0"

      if SuSEFirewall.IsEnabled
        # FIXME: missing support for setting IPv6 forwarding enablement in 
        # SuSEFirewall module and in SuSEFirewall2 at all
        SuSEFirewall.SetSupportRoute(@Forward_v4)
      else
        SCR.Write(
          path(SYSCTL_IPV4_PATH),
          forward_ipv4
        )
        SCR.Write(
          path(SYSCTL_IPV6_PATH),
          forward_ipv6
        )
        SCR.Write(path(".etc.sysctl_conf"), nil)
      end

      SCR.Execute(
        path(".target.bash"),
        "echo #{forward_ipv4} > /proc/sys/net/ipv4/ip_forward"
      )
      SCR.Execute(
        path(".target.bash"),
        "echo #{forward_ipv6} > /proc/sys/net/ipv6/conf/all/forwarding",
      )

      nil
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

        # see man ifcfg - difference on implicit device param (aka "-") in
        # case of /etc/sysconfig/network/routes and /etc/sysconfig/network/
        # /ifroute-<device>
        dev_routes.map! do |route|
          route["device"] = device if route["device"] == "-"
          route
        end

        @Routes << dev_routes
      end

      @Routes.uniq!
      log.info("Routes=#{@Routes}")

      ReadIPForwarding()

      # save routes to check for changes later
      @Orig_Routes = deep_copy(@Routes)
      @Orig_Forward_v4 = @Forward_v4
      @Orig_Forward_v6 = @Forward_v6

      if @Routes.empty?
        ReadFromGateway(NetHwDetection.result["GATEWAY"] || "")
      end

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
      sl = 0 #100; //for testing

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      #Progress stage 1/2
      ProgressNextStage(_("Writing IP forwarding settings..."))

      WriteIPForwarding()
      Builtins.sleep(sl)

      # at first stop the running routes
      # FIXME SCR::Execute(.target.bash, "/etc/init.d/route stop");
      # sysconfig does not support restarting routes only,
      # so we let our caller do it together with other things

      #Progress stage 2/2
      ProgressNextStage(_("Writing routing settings..."))

      ret = write_routes(@Routes)

      # FIXME: no idea why sleep should be needed here. May be it had it's
      # meaning in /etc/init.d/routes times
      Builtins.sleep(sl)
      Progress.NextStage

      ret
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
      if SCR.Read(path(".target.size"), ROUTES_FILE) > 0
        SCR.Execute(
          path(".target.bash"),
          "/bin/cp #{ROUTES_FILE} #{ROUTES_FILE}.YaST2save"
        )
      else
        SCR.Write(path(".target.string"), ROUTES_FILE, "")
      end

      if routes.empty?
        # workaround bug [#4476]
        ret = SCR.Write(path(".target.string"), ROUTES_FILE, "")
      else
        ret = true

        # update the routes config
        Routing.devices.each do |device|
          ifroutes = routes.select { |r| r["device"] == device }
          written = SCR.Write(path(".ifroute-#{device}"), ifroutes) if !ifroutes.empty?
          ret &&= written
        end

        routes = routes.select { |r| r["device"] == "-" }
        ret = SCR.Write(path(".routes"), routes) && ret if !routes.empty?
      end

      return ret
    end


    # Get all the Routing configuration from a map.
    # When called by routing_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings autoinstallation settings
    # @return true if success
    def Import(settings)
      settings = deep_copy(settings)
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

      true
    end

    # Dump the Routing settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      exproute = {}

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
      if devs == nil
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

    publish :variable => :Routes, :type => "list <map>"
    publish :variable => :Forward_v4, :type => "boolean"
    publish :variable => :Forward_v6, :type => "boolean"
    publish :function => :Modified, :type => "boolean ()"
    publish :function => :ReadFromGateway, :type => "boolean (string)"
    publish :function => :RemoveDefaultGw, :type => "void ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :GetDevices, :type => "list ()"
    publish :function => :GetGateway, :type => "string ()"
    publish :function => :SetDevices, :type => "boolean (list)"
    publish :function => :Summary, :type => "string ()"

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
          term(:File, "/etc/sysconfig/network/ifroute-#{device}"),
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
    # @return [true,false] if succeed
    def register_ifroute_agent_for_device(device)
      SCR.RegisterAgent(path(".ifroute-#{device}"), ifroute_term(device))
    end

  end

  Routing = RoutingClass.new
  Routing.main
end
