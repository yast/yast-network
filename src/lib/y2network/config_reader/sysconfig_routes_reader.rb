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
require "y2network/routing_table"

require "yast"
require "y2network/interface"

module Y2Network
  module ConfigReader
    DEFAULT_ROUTES_FILE = "/etc/sysconfig/network/routes".freeze

    # This class reads the current configuration from a file in routes format
    # (@see man routes)
    class SysconfigRoutesReader
      # @param routes_file [<String>] full path to a file in routes format, when
      #                               not defined, then /etc/sysconfig/network/routes is used
      def initialize(routes_file: DEFAULT_ROUTES_FILE)
        @routes_file = if routes_file == DEFAULT_ROUTES_FILE
          Yast::Path.new(".routes")
        else
          register_ifroute_agent_for_path(routes_file)
        end
      end

      # Load routing tables
      #
      # Loads content of the routes file specified in the initialization
      #
      # @return [Y2Network::RoutingTable]
      def config
        routes = load_routes.map { |r| build_route(r) }
        Y2Network::RoutingTable.new(routes)
      end

    private

      MISSING_VALUE = "-".freeze
      private_constant :MISSING_VALUE
      DEFAULT_DEST = "default".freeze
      private_constant :DEFAULT_DEST

      # Loads routes from system
      #
      # @return [Array<Hash<String, String>>] list of hashes representing routes
      #                                       as provided by SCR agent.
      #                                       keys: destination, gateway, netmask, [device, [extrapara]]
      def load_routes
        routes = Yast::SCR.Read(@routes_file) || []
        normalize_routes(routes.uniq)
      end

      # Converts routes config as read from system into well-defined format
      #
      # Expects list of hashes as param. Hash should contain keys "destination",
      # "gateway", "netmask", "device", "extrapara"
      #
      # Currently it converts "destination" in CIDR format (<ip>/<prefix_len>)
      # and keeps just <ip> part in "destination" and puts "/<prefix_len>" into
      # "netmask"
      #
      # @param routes [Array<Hash>] in quad or CIDR flavors (see {#Routes})
      # @return [Array<Hash>] in quad or slash flavor
      def normalize_routes(routes)
        return routes if routes.nil? || routes.empty?

        routes.map do |route|
          subnet, prefix = route["destination"].split("/")

          next route if prefix.nil?

          route["destination"] = subnet
          route["netmask"] = "/#{prefix}"

          route
        end
      end

      # Given an IP and a netmask, returns a valid IPAddr object
      #
      # @param ip_str      [String] IP address; {MISSING_VALUE} means that the IP is not defined
      # @param netmask_str [String] Netmask; {MISSING_VALUE} means than no netmask was specified
      # @return [IPAddr,nil] The IP address or `nil` if the IP is missing
      def build_ip(ip_str, netmask_str = MISSING_VALUE)
        return nil if ip_str == MISSING_VALUE

        ip = IPAddr.new(ip_str)
        netmask_str == MISSING_VALUE ? ip : ip.mask(netmask_str)
      end

      # Build a route given a hash from the SCR agent
      #
      # @param hash [Hash] Hash from the `.routes` SCR agent
      # @return Route
      def build_route(hash)
        # TODO: check whether the iface is configured in the system
        iface = Interface.new(hash["device"])
        # normalized SCR output contains either subnet mask or /<prefix length> under
        # "netmask" key
        # TODO: this should be improved in normalize_routes
        mask = hash["netmask"] =~ /\/[0-9]+/ ? hash["netmask"][1..-1] : hash["netmask"]

        Y2Network::Route.new(
          to:        hash["destination"] != DEFAULT_DEST ? build_ip(hash["destination"], mask) : :default,
          interface: iface,
          gateway:   build_ip(hash["gateway"], MISSING_VALUE),
          options:   hash["extrapara"] || ""
        )
      end

      # SCR agent for routes files definition
      def ifroute_term(path)
        raise ArgumentError if path.nil? || path.empty?

        non_empty_str_term = Yast::term(:String, "^ \t\n")
        whitespace_term = Yast::term(:Whitespace)
        optional_whitespace_term = Yast::term(:Optional, whitespace_term)
        routes_content_term = Yast::term(
          :List,
          Yast::term(
            :Tuple,
            Yast::term(
              :destination,
              non_empty_str_term
            ),
            whitespace_term,
            Yast::term(:gateway, non_empty_str_term),
            whitespace_term,
            Yast::term(:netmask, non_empty_str_term),
            optional_whitespace_term,
            Yast::term(
              :Optional,
              Yast::term(:device, non_empty_str_term)
            ),
            optional_whitespace_term,
            Yast::term(
              :Optional,
              Yast::term(
                :extrapara,
                Yast::term(:String, "^\n")
              )
            )
          ),
          "\n"
        )

        Yast::term(
          :ag_anyagent,
          Yast::term(
            :Description,
            Yast::term(:File, path),
            "#\n",
            false,
            routes_content_term
          )
        )
      end

      # Registers SCR agent which is used for accessing particular ifroute-device
      # file
      #
      # @param device [String] full path to a file in routes format (e.g. /etc/sysconfig/network/ifroute-eth0)
      # @return [Path] SCR path of the agent
      # @raise  [RuntimeError] if it fails
      def register_ifroute_agent_for_path(path)
        # /etc/sysconfig/network/ifroute-eth0 define .ifroute-eth0 agent
        # TODO: collisions not handled
        scr_path = Yast::Path.new(".#{File.basename(path)}")
        Yast::SCR.RegisterAgent(scr_path, ifroute_term(path)) ||
          raise("Cannot register agent (#{scr_path})")
        scr_path
      end
    end
  end
end
