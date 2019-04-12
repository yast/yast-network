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

require "yast"
require "y2network/config"
require "y2network/config_writer/sysconfig"
require "y2network/serializer/route_sysconfig"

Yast.import "Lan"
Yast.import "UI"
Yast.import "Label"
Yast.import "Wizard"

Yast.import "CommandLine"
Yast.import "String"
Yast.import "NetworkService"

module Y2Network
  module Clients
    # Routing client for configuring IP Forwarding and Network Routes
    class Routing < Yast::Client
      include Yast::Logger

      # Constructor
      def initialize
        textdomain "network"
      end

      def main
        log_and_return { CommandLine.Run(cmdline_definition) }
      end

    private

      def log_and_return(&block)
        # The main ()
        log.info("----------------------------------------")
        log.info("Routing module started")
        ret = block.call
        log.debug("ret=#{ret}")
        # Finish
        log.info("Routing module finished")
        log.info("----------------------------------------")
        ret
      end

      # Main Routing GUI
      def RoutingGUI
        read
        Yast.include self, "network/services/routing.rb"

        Wizard.CreateDialog
        Wizard.SetDesktopTitleAndIcon("routing")
        Wizard.SetNextButton(:next, Label.FinishButton)

        # main ui function
        ret = RoutingMainDialog()
        log.debug("ret == #{ret}")

        if ret == :next && modified?
          write
          NetworkService.StartStop
        end

        UI.CloseDialog
        ret
      end

      # Creates a text printable routing table with the given routes
      #
      # @param routes [Array<Y2Network::Route>]
      # @return [String]
      def PrintableRoutingTable(routes)
        table_items =
          routes.map do |route|
            route_hash = serializer.to_hash(route)
            %w(destination gateway netmask device extrapara).map { |attr| route_hash[attr] }
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

        headline + "\n" + table
      end

      # Handler for action "list"
      #
      # @param _options [Hash{String => String}] action options
      def ListHandler(_options)
        CommandLine.Print(PrintableRoutingTable(current_routes))
        CommandLine.Print("")

        true
      end

      # Handler for action "show"
      #
      # @param options [Hash{String => String}] action options
      def ShowHandler(options)
        destination = options["dest"]
        routes = destination_routes(destination)

        if routes.empty?
          CommandLine.Error(
            Builtins.sformat(
              _("No entry for destination '%1' in routing table"), destination
            )
          )
          return false
        end

        CommandLine.Print(PrintableRoutingTable(routes))
        CommandLine.Print("")

        true
      end

      def forwarding_handler(options, protocol)
        forward_ivars = {
          "IPv4" => :forward_ipv4,
          "IPv6" => :forward_ipv6
        }
        forward_ivar = forward_ivars[protocol]

        return false unless forward_ivar

        if options["show"]
          if yast_config.routing.public_send(forward_ivar)
            # translators: %s is "IPv4" or "IPv6"
            CommandLine.Print(_("%s forwarding is enabled") % protocol)
          else
            # translators: %s is "IPv4" or "IPv6"
            CommandLine.Print(_("%s forwarding is disabled") % protocol)
          end
        elsif options["on"]
          # translators: %s is "IPv4" or "IPv6"
          CommandLine.Print(_("Enabling %s forwarding...") % protocol)
          yast_config.routing.public_send("#{forward_ivar}=", true)
        elsif options["off"]
          # translators: %s is "IPv4" or "IPv6"
          CommandLine.Print(_("Disabling %s forwarding...") % protocol)
          yast_config.routing.public_send("#{forward_ivar}=", false)
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

      def route_from_options(options)
        serializer.from_hash(
          "destination" => options.fetch("dest", "default"),
          "gateway"     => options.fetch("gateway", "-"),
          "netmask"     => options.fetch("netmask", "-"),
          "device"      => options.fetch("dev", "-"),
          "extrapara"   => options["options"]
        )
      end

      def serializer
        @serializer ||= Y2Network::Serializer::RouteSysconfig.new
      end

      def update_route_with!(route, edited_route)
        route.to      = edited_route.to
        route.gateway = edited_route.gateway
        route.options = edited_route.options
        route.interface = edited_route.interface
      end

      # Convenience method to obtain all the routes which has the given
      # destination
      #
      #
      def destination_routes(destination)
        current_routes.select { |r| serializer.to_hash(r)["destination"] == destination }
      end

      # Handler for action "add"
      #
      # @param options [Hash{String => String}] action options
      # @return [Boolean] true if added; false otherwise
      def AddHandler(options)
        destination = options["dest"]

        unless destination
          CommandLine.Error(_("At least destination must be specified."))
          return false
        end

        route = route_from_options(options)

        CommandLine.Print(
          Builtins.sformat(_("Adding '%1' destination to routing table ..."), destination)
        )

        yast_routing_table.routes << route if !yast_routing_table.routes.include?(route)

        true
      end

      # Handler for action "edit"
      #
      # @param options [Hash{String => String}] action options
      # @return [Boolean] true if edited; false otherwise
      def EditHandler(options)
        destination = options["dest"]

        if destination == ""
          CommandLine.Error(_("Destination IP address must be specified."))
          return false
        end

        if options.size < 2
          CommandLine.Error(
            _(
              "At least one of the following parameters (gateway, netmask, device, options) must be specified"
            )
          )
          return false
        end

        route = destination_routes(destination).first

        if route
          edited_route = route_from_options(options)
          CommandLine.Print(
            Builtins.sformat(
              _("Updating '%1' destination in routing table ..."),
              destination
            )
          )

          update_route_with!(route, edited_route)
        else
          CommandLine.Error(
            Builtins.sformat(
              _("No entry for destination '%1' in routing table"),
              destination
            )
          )
          return false
        end

        true
      end

      # Handler for action "delete"
      #
      # @param [Hash]
      # @return [Boolean] true if deleted; false otherwise
      def DeleteHandler(options)
        destination = options["dest"]
        route = destination_routes(destination).first

        if route
          CommandLine.Print(
            Builtins.sformat(
              _("Deleting '%1' destination from routing table ..."),
              destination
            )
          )
          yast_routing_table.routes.delete(route)
        else
          CommandLine.Error(
            Builtins.sformat(
              _("No entry for destination '%1' in routing table"),
              destination
            )
          )
        end

        !!route
      end

      # Initialize the yast and system {Y2Network::Config}s from the sysconfig
      #
      # @return [Boolean]
      def read
        # Collisions not expected, but who knows what happens during new backend development
        raise "The configuration is already loaded" if Y2Network::Config.find(:system)

        system_config = Y2Network::Config.from(:sysconfig)
        Yast::Config.add(:system, system_config)
        Yast::Config.add(:yast, system_config.copy)

        true
      end

      # Write down the :yast {Y2Network::Config} in case of modified
      #
      # @return [Boolean]
      def write
        if modified?
          Y2Network::ConfigWriter::Sysconfig.new.write(yast_config)
          log.info("Writing routing configuration: #{yast_config.routing.inspect}")
        end

        true
      end

      # Whether the :yast {Y2Network::Config} has been modified since read or
      # not
      #
      # @return [Boolean]
      def modified?
        yast_config.routing != system_config.routing
      end

      # Convenience method to obtain the current :yast {Y2Network::Config}
      #
      # @return [Y2Network::Config]
      def yast_config
        Y2Network::Config.find(:yast)
      end

      # Convenience method to obtain the current :yast {Y2Network::Config}
      #
      # @return [Y2Network::Config]
      def system_config
        Y2Network::Config.find(:system)
      end

      # Convenience method to obtain the current :yast {Y2Network::Config}
      # {Y2Network::RoutingTable}
      #
      # @return [Y2Network::RoutingTable]
      def yast_routing_table
        yast_config.routing.tables.first
      end

      # Convenience method to obtain current :yast {Y2Network::Route}s
      #
      # @return [Array<Y2Network::Route>]
      def current_routes
        return [] unless yast_config && yast_config.routing

        yast_config.routing.routes
      end

      # Command line definition
      def cmdline_definition
        {
          # Commandline help title
          "help"       => _("Routing Configuration"),
          "id"         => "routing",
          "guihandler" => fun_ref(method(:RoutingGUI), "any ()"),
          "initialize" => fun_ref(method(:read), "boolean ()"),
          "finish"     => fun_ref(method(:write), "boolean ()"),
          "actions"    => {
            "list"            => {
              "help"    => _("Show complete routing table"),
              "handler" => fun_ref(method(:ListHandler), "boolean ()")
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
      end
    end
  end
end
