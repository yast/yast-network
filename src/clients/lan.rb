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
# File:	clients/lan.ycp
# Package:	Network configuration
# Summary:	Network cards main file
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for network card configuration.
# Uses all other files.
module Yast
  class LanClient < Client
    def main
      Yast.import "UI"

      # **
      # <h3>Network configuration</h3>

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Lan module started")

      Yast.import "CommandLine"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "RichText"

      Yast.include self, "network/lan/cmdline.rb"
      Yast.include self, "network/lan/wizards.rb"

      # Command line definition
      @cmdline = {
        # Commandline help title
        "help"       => _("Network Card Configuration"),
        "id"         => "lan",
        "guihandler" => fun_ref(method(:LanSequence), "symbol ()"),
        "initialize" => fun_ref(Lan.method(:ReadWithCacheNoGUI), "boolean ()"),
        "finish"     => fun_ref(Lan.method(:Write), "boolean ()"),
        "actions"    => {
          "list"   => {
            # Commandline command help
            "help"    => _(
              "Display configuration summary"
            ),
            "example" => "lan list configured",
            "handler" => fun_ref(
              method(:ListHandler),
              "boolean (map <string, string>)"
            )
          },
          "show"   => {
            # Commandline command help
            "help"    => _(
              "Display configuration summary"
            ),
            "example" => "lan show id=0",
            "handler" => fun_ref(
              method(:ShowHandler),
              "boolean (map <string, string>)"
            )
          },
          "add"    => {
            # Commandline command help
            "help"    => _("Add a network card"),
            "handler" => fun_ref(
              method(:AddHandler),
              "boolean (map <string, string>)"
            ),
            "example" => [
              "yast lan add name=vlan50 ethdevice=eth0 bootproto=dhcp",
              "yast lan add name=br0 bridge_ports=eth0 eth1 bootproot=dhcp",
              "yast lan add name=bond0 slaves=eth0 eth1 bootproto=dhcp"
            ]
          },
          "edit"   => {
            "help"    => _("Change existing configuration"),
            "handler" => fun_ref(
              method(:EditHandler),
              "boolean (map <string, string>)"
            )
          },
          "delete" => {
            # Commandline command help
            "help"    => _("Delete a network card"),
            "handler" => fun_ref(
              method(:DeleteHandler),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          "configured"   => {
            # Commandline option help
            "help" => _("List only configured cards")
          },
          "unconfigured" => {
            # Commandline option help
            "help" => _(
              "List only unconfigured cards"
            )
          },
          "device"       => {
            # Commandline option help
            "help" => _("Device identifier"),
            "type" => "string"
          },
          "id"           => {
            # Commandline option help
            "help" => _("Config identifier"),
            "type" => "string"
          },
          "bootproto"    => {
            # Commandline option help
            "help" => _("Use static or dynamic configuration"),
            "type" => "string"
          },
          "name"         => {
            "help" => _("Configuration Name"),
            "type" => "string"
          },
          "ip"           => {
            # Commandline option help
            "help" => _("Device IP address"),
            "type" => "ip"
          },
          "netmask"      => {
            # Commandline option help
            "help" => _("Network mask"),
            "type" => "netmask"
          },
          "prefix"       => {
            # Commandline option help
            "help" => _("Prefix length"),
            "type" => "string"
          },
          "slaves"       => {
            # Commandline option help
            "help" => _("Bond Slaves"),
            "type" => "string"
          },
          "ethdevice"    => {
            # Commandline option help
            "help" => _("Ethernet Device for VLAN"),
            "type" => "string"
          },
          "bridge_ports" => {
            # Commandline option help
            "help" => _("Interfaces for Bridging"),
            "type" => "string"
          }
        },
        "mappings"   => {
          "list"   => ["configured", "unconfigured"],
          "show"   => ["id"],
          "add"    => [
            "name",
            "bootproto",
            "ip",
            "netmask",
            "prefix",
            "slaves",
            "ethdevice",
            "bridge_ports"
          ],
          "edit"   => ["id", "bootproto", "ip", "netmask", "prefix"],
          "delete" => ["id"]
        }
      }

      @ret = CommandLine.Run(@cmdline)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Lan module finished")
      Builtins.y2milestone("----------------------------------------")

      # EOF

      @ret
    end
  end
end

Yast::LanClient.new.main
