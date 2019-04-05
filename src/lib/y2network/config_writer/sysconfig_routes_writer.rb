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
require "y2network/sysconfig_routes"

module Y2Network
  module ConfigWriter
    # This class writes the current routes into a file in routes format
    # (@see man routes)
    class SysconfigRoutesWriter
      include SysconfigRoutes

      # @param routes_file [<String>] full path to a file in routes format, when
      #                               not defined, then /etc/sysconfig/network/routes is used
      def initialize(routes_file: DEFAULT_ROUTES_FILE)
        @routes_file = if routes_file == DEFAULT_ROUTES_FILE
          Yast::Path.new(".routes")
        else
          register_ifroute_agent_for_path(routes_file)
        end
      end

      # Writes configured routes
      #
      # @param routes [Array<Route>] list of routes
      # @return [Boolean] true on success
      def write(routes)
        # create if not exists, otherwise backup
        if Yast::FileUtils.Exists(@routes_file)
          Yast::SCR.Execute(
            Yast::Path.new(".target.bash"),
            "/bin/cp #{@routes_file} #{@routes_file}.YaST2save"
          )
        else
          Yast::SCR.Write(Yast::Path.new(".target.string"), @routes_file, "")
        end

        clear_routes_file if routes.empty?

        Yast::SCR.Write(@routes_file, routes.map { |r| route_to_hash(r) })
      end

    private

      # Clear file with routes definitions for particular device
      #
      # @return [true, false] if succeedes
      def clear_routes_file
        # work around bnc#19476
        if @routes_file == Yast::Path.new(DEFAULT_ROUTES_FILE)
          Yast::SCR.Write(path(".target.string"), DEFAULT_ROUTES_FILE, "")
        else
          filename = @routes_file.to_s.tr(".", "/")

          return Yast::SCR.Execute(path(".target.remove"), filename) if FileUtils.Exists(filename)
          true
        end
      end

      # Returns a hash containing the route information
      #
      # Hash is provided in format suitable for .etc.routes SCR agent
      #
      # @param route [Y2Network::Route]
      # @return [Hash]
      def route_to_hash(route)
        hash = if route.default?
          { "destination" => "default", "netmask" => "-" }
        else
          dest = route.to
          # netmask column of routes file has been marked as deprecated -> using prefix
          { "destination" => "#{dest}/#{dest.prefix}", "netmask" => "-" }
        end

        hash.merge("options" => route.options) unless route.options.to_s.empty?
        hash.merge(
          "gateway" => route.gateway ? route.gateway.to_s : "-",
          "device"  => route.interface == :any ? "-" : route.interface.name
        )
      end
    end
  end
end
