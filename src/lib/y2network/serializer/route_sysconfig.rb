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
require "y2network/route"

module Y2Network
  module Serializer
    # This class is responsible of serializing {Y2Network::Route}s from a hash
    # and to a hash representation based on sysconfig routing configuration.
    class RouteSysconfig
      DEFAULT_DEST = "default".freeze
      MISSING_VALUE = "-".freeze

      # Returns a hash representation of the {Y2Network::Route} object based
      # on sysconfig route files syntax
      #
      # @param route [Y2Network::Route]
      # @return [Hash] based on sysconfig route files syntax
      def to_hash(route)
        hash = if route.default?
          { "destination" => "default", "netmask" => "-" }
        else
          dest = route.to
          # netmask column of routes file has been marked as deprecated -> using prefix
          { "destination" => "#{dest}/#{dest.prefix}", "netmask" => "-" }
        end

        hash["extrapara"] = route.options unless route.options.to_s.empty?
        hash["gateway"] = route.gateway ? route.gateway.to_s : "-"
        hash["device"] = route.interface == :any ? "-" : route.interface.name
        hash
      end

      # Build a route given a hash based on sysconfig route files syntax
      #
      # @param hash [Hash] based on sysconfig route files syntax
      # @return [Y2Network::Route]
      def from_hash(hash)
        Y2Network::Route.new(
          to:        destination_from(hash),
          interface: interface_from(hash),
          gateway:   build_ip(hash["gateway"]),
          options:   hash["extrapara"] || ""
        )
      end

    private

      # Given an IP and a netmask, returns a valid IPAddr object
      #
      # @param ip_str      [String] IP address; {MISSING_VALUE} means that the IP is not defined
      # @param netmask_str [String] Netmask; {MISSING_VALUE} means that no netmask was specified
      # @return [IPAddr,nil] The IP address or `nil` if the IP is missing
      def build_ip(ip_str, netmask_str = MISSING_VALUE)
        return nil if ip_str == MISSING_VALUE

        ip = IPAddr.new(ip_str)
        netmask_str == MISSING_VALUE ? ip : ip.mask(netmask_str)
      end

      # @return [Y2Network::Interface, :any]
      def interface_from(hash)
        return :any if hash.fetch("device", "-") == MISSING_VALUE

        Y2Network::Interface.new(hash["device"])
      end

      # normalized SCR output contains either subnet mask or /<prefix length> under
      # "netmask" key
      def destination_from(hash)
        return :default if hash["destination"] == DEFAULT_DEST
        netmask = hash.fetch("netmask", MISSING_VALUE).delete("/")
        build_ip(hash["destination"], netmask)
      end
    end
  end
end
