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

require "yast"
Yast.import "Routing"

module Y2Network
  module ConfigWriter
    class Sysconfig
      def write(config)
        routes = config.routes.map { |r| route_to_hash(r) }
        Yast::Routing.Import("routes" => routes)
      end

    private

      def route_to_hash(route)
        hash =
          if route.default?
            { "destination" => "-", "netmask" => "-" }
          else
            { "destination" => route.to.to_s, "netmask" => netmask(route.to) }
          end
        hash.merge(
          "gateway" => route.gateway ? route.gateway.to_s : "-",
          "device" => route.interface == :any ? "-" : route.interface.name
        )
      end

      IPV4_MASK = "255.255.255.255".freeze
      IPV6_MASK = "fffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff".freeze
      def netmask(ip)
        mask = ip.ipv4? ? IPV4_MASK : IPV6_MASK
        IPAddr.new(mask).mask(ip.prefix).to_s
      end
    end
  end
end
