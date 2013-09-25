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
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetHwDetection"
      Yast.import "NetworkInterfaces"
      Yast.import "Map"
      Yast.import "SuSEFirewall"

      Yast.include self, "network/runtime.rb"
      Yast.include self, "network/routines.rb"

      # All routes
      # list <map <string, string> >:
      # keys: destination, gateway, netmask, [device, [extrapara]]
      @Routes = []

      # modified by AY (bnc#649494)
      @modified = nil
      # Enable IP forwarding
      # .etc.sysctl_conf."net.ipv4.ip_forward"
      @Forward_v4 = false

      # List of available devices
      @devices = []

      # All routes read at the start
      @Orig_Routes = nil
      @Orig_Forward_v4 = nil

      # "routes" file location
      @routes_file = "/etc/sysconfig/network/routes"
    end

    # Data was modified?
    # @return true if modified
    def Modified
      ret = @Routes != @Orig_Routes || @Forward_v4 != @Orig_Forward_v4
      # probably called without Read()  (bnc#649494)
      if @Orig_Routes == nil && @Orig_Forward_v4 == nil && @modified != true
        ret = false
      end
      Builtins.y2debug("ret=%1", ret)
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
      else
        @Forward_v4 = SCR.Read(path(".etc.sysctl_conf.\"net.ipv4.ip_forward\"")) == "1"
      end

      nil
    end

    def WriteIPForwarding
      if SuSEFirewall.IsEnabled
        SuSEFirewall.SetSupportRoute(@Forward_v4)
      else
        SCR.Write(
          path(".etc.sysctl_conf.\"net.ipv4.ip_forward\""),
          @Forward_v4 ? "1" : "0"
        )
        SCR.Write(
          path(".etc.sysctl_conf.\"net.ipv6.conf.all.forwarding\""),
          @Forward_v4 ? "1" : "0"
        )
        SCR.Write(path(".etc.sysctl_conf"), nil)
      end
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "echo %1 > /proc/sys/net/ipv4/ip_forward",
          @Forward_v4 ? 1 : 0
        )
      )
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat(
          "echo %1 > /proc/sys/net/ipv6/conf/all/forwarding",
          @Forward_v4 ? 1 : 0
        )
      )

      nil
    end

    # Read routing settings
    # If no routes, sets a default gateway from Detection
    # @return true if success
    def Read
      # read route.conf
      if Ops.greater_than(SCR.Read(path(".target.size"), @routes_file), 0)
        @Routes = Convert.convert(
          SCR.Read(path(".routes")),
          :from => "any",
          :to   => "list <map>"
        )
      else
        @Routes = []
      end

      ReadIPForwarding()

      Builtins.y2debug("Routes=%1", @Routes)
      Builtins.y2debug("Forward_v4=%1", @Forward_v4)

      # save routes to check for changes later
      @Orig_Routes = Builtins.eval(@Routes)
      @Orig_Forward_v4 = Builtins.eval(@Forward_v4)

      # read available devices
      NetworkInterfaces.Read
      @devices = NetworkInterfaces.List("")

      if @Routes == []
        ReadFromGateway(Ops.get_string(NetHwDetection.result, "GATEWAY", ""))
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

      # create if not exists, otherwise backup
      if Ops.less_than(SCR.Read(path(".target.size"), @routes_file), 0)
        SCR.Write(path(".target.string"), @routes_file, "")
      else
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(
              Ops.add(Ops.add("/bin/cp ", @routes_file), " "),
              @routes_file
            ),
            ".YaST2save"
          )
        )
      end

      ret = false
      if @Routes == []
        # workaround bug [#4476]
        ret = SCR.Write(path(".target.string"), @routes_file, "")
      else
        # update the routes config
        ret = SCR.Write(path(".routes"), @Routes)
      end
      Builtins.sleep(sl)
      Progress.NextStage

      # and finally set up the new routes
      # FIXME SCR::Execute(.target.bash, "/etc/init.d/route start");

      ret == true
    end


    # Get all the Routing configuration from a map.
    # When called by routing_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings autoinstallation settings
    # @return true if success
    def Import(settings)
      settings = deep_copy(settings)
      @Routes = Builtins.eval(Ops.get_list(settings, "routes", []))
      @Forward_v4 = Ops.get_boolean(settings, "ip_forward", false)

      @Orig_Routes = nil
      @Orig_Forward_v4 = nil

      @modified = true

      true
    end

    # Dump the Routing settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      exproute = {}
      if Ops.greater_than(Builtins.size(Builtins.eval(@Routes)), 0)
        Ops.set(exproute, "routes", Builtins.eval(@Routes))
      end
      Ops.set(exproute, "ip_forward", @Forward_v4)
      deep_copy(exproute)
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
    # @return summary text
    def Summary
      return "" if Ops.less_than(Builtins.size(@Routes), 1)

      Yast.import "Summary"
      summary = ""

      gw = GetGateway()
      gwhost = NetHwDetection.ResolveIP(gw)
      gw = Ops.add(Ops.add(Ops.add(gw, " ("), gwhost), ")") if gwhost != ""

      if gw != ""
        # Summary text
        summary = Summary.AddListItem(
          summary,
          Builtins.sformat(_("Gateway: %1"), gw)
        ) 
        # summary = add(summary, Summary::Device(sformat(_("Gateway: %1"), gw), ""));
      end

      if @Forward_v4 == true
        # Summary text
        summary = Summary.AddListItem(summary, _("IP Forwarding for IPv4: on"))
      else
        # summary = add(summary, Summary::Device(_("IP Forwarding: on"), ""));

        # Summary text
        summary = Summary.AddListItem(summary, _("IP Forwarding for IPv4: off"))
      end
      # summary = add(summary, Summary::Device(_("IP Forwarding: off"), ""));

      if @Routes != []
        # Summary text
        # summary = add(summary, Summary::Device(sformat(_("Routes: %1"), Routes), ""));
        Builtins.y2debug("not adding Routes to summary")
      end

      return "" if Ops.less_than(Builtins.size(summary), 1)
      Ops.add(Ops.add("<ul>", summary), "</ul>")
    end

    publish :variable => :Routes, :type => "list <map>"
    publish :variable => :Forward_v4, :type => "boolean"
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
  end

  Routing = RoutingClass.new
  Routing.main
end
