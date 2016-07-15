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
# File:	clients/routing.ycp
# Package:	Network configuration
# Summary:	Routing client
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for routing configuration.
# Uses all other files.
module Yast
  class RoutingClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Routing module started")

      Yast.import "Label"
      Yast.import "Routing"
      Yast.import "Wizard"

      Yast.import "CommandLine"
      Yast.import "String"
      Yast.import "RichText"
      Yast.import "NetworkService"

      Yast.include self, "network/services/routing.rb"

      # Command line definition
      @cmdline = {
        # Commandline help title
        "help"       => _("Routing Configuration"),
        "id"         => "routing",
        "guihandler" => fun_ref(method(:RoutingGUI), "any ()"),
        "initialize" => fun_ref(Routing.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Routing.method(:Write), "boolean ()"), # FIXME
        "actions"    => {
          "list"            => {
            "help"    => _("Show complete routing table"),
            "handler" => fun_ref(
              method(:ListHandler),
              "boolean (map <string, string>)"
            )
          },
          "show"            => {
            "help"    => _("Show routing table entry for selected destination"),
            "handler" => fun_ref(
              method(:ShowHandler),
              "boolean (map <string, string>)"
            ),
            "example" => "show dest=10.10.1.0"
          },
          "ip-forwarding"   => {
            "help"    => _("IPv4 and IPv6 forwarding settings"),
            "handler" => fun_ref(
              method(:IPFWHandler),
              "boolean (map <string, string>)"
            ),
            "example" => ["ip-forwarding show", "ip-forwarding on"]
          },
          "ipv4-forwarding" => {
            "help"    => _("IPv4 only forwarding settings"),
            "handler" => fun_ref(
              method(:IPv4FWHandler),
              "boolean (map <string, string>)"
            ),
            "example" => ["ipv4-forwarding show", "ipv4-forwarding on"]
          },
          "ipv6-forwarding" => {
            "help"    => _("IPv6 only forwarding settings"),
            "handler" => fun_ref(
              method(:IPv6FWHandler),
              "boolean (map <string, string>)"
            ),
            "example" => ["ipv6-forwarding show", "ipv6-forwarding on"]
          },
          "add"             => {
            "help"    => _("Add new route"),
            "handler" => fun_ref(
              method(:AddHandler),
              "boolean (map <string, string>)"
            ),
            "example" => "add dest=10.10.1.0 gateway=10.10.1.1 netmask=255.255.255.0"
          },
          "edit"            => {
            "help"    => _("Edit an existing route"),
            "handler" => fun_ref(
              method(:EditHandler),
              "boolean (map <string, string>)"
            ),
            "example" => "edit dest=10.10.1.0 gateway=10.10.1.1 netmask=255.255.255.0"
          },
          "delete"          => {
            "help"    => _("Delete an existing route"),
            "handler" => fun_ref(
              method(:DeleteHandler),
              "boolean (map <string, string>)"
            ),
            "example" => "delete dest=10.10.1.0"
          }
        },
        "options"    => {
          "dest"    => {
            "type" => "string",
            "help" => _("Destination IP address")
          },
          "gateway" => { "type" => "string", "help" => _("Gateway IP address") },
          "netmask" => { "type" => "string", "help" => _("Subnet mask") },
          "dev"     => { "type" => "string", "help" => _("Network device") },
          "options" => { "type" => "string", "help" => _("Additional options") },
          "show"    => { "help" => _("Show current settings") },
          "on"      => { "help" => _("Enable IP forwarding") },
          "off"     => { "help" => _("Disable IP forwarding") }
        },
        "mappings"   => {
          "show"            => ["dest"],
          "ip-forwarding"   => ["show", "on", "off"],
          "ipv4-forwarding" => ["show", "on", "off"],
          "ipv6-forwarding" => ["show", "on", "off"],
          "add"             => ["dest", "gateway", "netmask", "dev", "options"],
          "edit"            => ["dest", "gateway", "netmask", "dev", "options"],
          "delete"          => ["dest"]
        }
      }

      @ret = CommandLine.Run(@cmdline)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Routing module finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      Routing.Modified
    end

    # Main Routing GUI
    def RoutingGUI
      Routing.Read

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("routing")
      Wizard.SetNextButton(:next, Label.FinishButton)

      # main ui function
      ret = RoutingMainDialog()
      Builtins.y2debug("ret == %1", ret)

      if ret == :next && Routing.Modified
        Routing.Write
        NetworkService.StartStop
      end

      UI.CloseDialog
      deep_copy(ret)
    end

    def PrintableRoutingTable(items)
      items = deep_copy(items)
      table_items = []
      Builtins.foreach(items) do |route|
        table_items = Builtins.add(
          table_items,
          [
            Ops.get_string(route, "destination", ""),
            Ops.get_string(route, "gateway", ""),
            Ops.get_string(route, "netmask", "-"),
            Ops.get_string(route, "device", "-"),
            Ops.get_string(route, "extrapara", "")
          ]
        )
      end

      headline = String.UnderlinedHeader(_("Routing Table"), 0)
      table = String.TextTable(
        [
          _("Destination"),
          _("Gateway"),
          _("Netmask"),
          _("Device"),
          _("Options")
        ],
        table_items,
        {}
      )

      Ops.add(Ops.add(headline, "\n"), table)
    end

    # Handler for action "list"
    # @param [Hash{String => String}] options action options
    def ListHandler(_options)
      CommandLine.Print(PrintableRoutingTable(Routing.Routes))
      CommandLine.Print("")

      true
    end

    def ShowHandler(options)
      options = deep_copy(options)
      routes = Builtins.filter(Routing.Routes) do |route|
        Ops.get_string(route, "destination", "") == Ops.get(options, "dest", "")
      end

      if routes != [] && !routes.nil?
        CommandLine.Print(PrintableRoutingTable(routes))
        CommandLine.Print("")
      else
        CommandLine.Error(
          Builtins.sformat(
            _("No entry for destination '%1' in routing table"),
            Ops.get(options, "dest", "")
          )
        )
        return false
      end

      true
    end

    def forwarding_handler(options, protocol)
      forward_ivars = {
        "IPv4" => :@Forward_v4,
        "IPv6" => :@Forward_v6
      }
      forward_ivar = forward_ivars[protocol]

      return false unless forward_ivar

      if !Ops.get(options, "show").nil?
        if Routing.instance_variable_get(forward_ivar)
          # translators: %s is "IPv4" or "IPv6"
          CommandLine.Print(_("%s forwarding is enabled") % protocol)
        else
          # translators: %s is "IPv4" or "IPv6"
          CommandLine.Print(_("%s forwarding is disabled") % protocol)
        end
      elsif !Ops.get(options, "on").nil?
        # translators: %s is "IPv4" or "IPv6"
        CommandLine.Print(_("Enabling %s forwarding...") % protocol)
        Routing.instance_variable_set(forward_ivar, true)
      elsif !Ops.get(options, "off").nil?
        # translators: %s is "IPv4" or "IPv6"
        CommandLine.Print(_("Disabling %s forwarding...") % protocol)
        Routing.instance_variable_set(forward_ivar, false)
      end
    end

    def IPv4FWHandler(options)
      CommandLine.Print(String.UnderlinedHeader(_("IPv4 Forwarding:"), 0))

      CommandLine.Print("")
      forwarding_handler(options, "IPv4")
      CommandLine.Print("")

      true
    end

    def IPv6FWHandler(options)
      CommandLine.Print(String.UnderlinedHeader(_("IPv6 Forwarding:"), 0))

      CommandLine.Print("")
      forwarding_handler(options, "IPv6")
      CommandLine.Print("")

      true
    end

    def IPFWHandler(options)
      CommandLine.Print(String.UnderlinedHeader(_("IPv4 and IPv6 Forwarding:"), 0))

      CommandLine.Print("")
      forwarding_handler(options, "IPv4")
      forwarding_handler(options, "IPv6")
      CommandLine.Print("")

      true
    end

    def AddEditHandler(addedit, options)
      options = deep_copy(options)
      routes = deep_copy(Routing.Routes)
      destination = Ops.get(options, "dest", "")
      gateway = Ops.get(options, "gateway", "")
      netmask = Ops.get(options, "netmask", "-")
      device = Ops.get(options, "dev", "-")
      extrapara = Ops.get(options, "options", "")

      if addedit == :add
        if destination == "" || gateway == ""
          CommandLine.Error(
            _(
              "At least destination and gateway IP addresses must be specified."
            )
          )
          return false
        end

        CommandLine.Print(
          Builtins.sformat(
            _("Adding '%1' destination to routing table ..."),
            destination
          )
        )
        routes = Builtins.add(
          routes,
          "destination" => destination,
          "gateway"     => gateway,
          "netmask"     => netmask,
          "device"      => device,
          "extrapara"   => extrapara
        )
      elsif addedit == :edit
        if destination == ""
          CommandLine.Error(_("Destination IP address must be specified."))
          return false
        end
        if Ops.less_than(Builtins.size(options), 2)
          CommandLine.Error(
            _(
              "At least one of the following parameters (gateway, netmask, device, options) must be specified"
            )
          )
          return false
        end

        found = false
        routes = Builtins.maplist(routes) do |m|
          if Ops.get(m, "destination") == destination
            Ops.set(m, "gateway", gateway)
            Ops.set(m, "netmask", netmask)
            Ops.set(m, "device", device)
            Ops.set(m, "extrapara", extrapara)
            found = true
          end
          deep_copy(m)
        end

        if found
          CommandLine.Print(
            Builtins.sformat(
              _("Updating '%1' destination in routing table ..."),
              destination
            )
          )
        else
          CommandLine.Error(
            Builtins.sformat(
              _("No entry for destination '%1' in routing table"),
              destination
            )
          )
          return false
        end
      end

      Routing.Routes = deep_copy(routes)
      true
    end

    def AddHandler(options)
      options = deep_copy(options)
      AddEditHandler(:add, options)
      true
    end

    def EditHandler(options)
      options = deep_copy(options)
      AddEditHandler(:edit, options)
      true
    end

    def DeleteHandler(options)
      options = deep_copy(options)
      found = false
      Routing.Routes = Builtins.maplist(Routing.Routes) do |m|
        next deep_copy(m) if Ops.get(m, "destination") != Ops.get(options, "dest")

        found = true
      end

      if found
        CommandLine.Print(
          Builtins.sformat(
            _("Deleting '%1' destination from routing table ..."),
            Ops.get(options, "dest", "")
          )
        )
        return true
      else
        CommandLine.Error(
          Builtins.sformat(
            _("No entry for destination '%1' in routing table"),
            Ops.get(options, "dest", "")
          )
        )
        return false
      end

      true
    end
  end
end

Yast::RoutingClient.new.main
