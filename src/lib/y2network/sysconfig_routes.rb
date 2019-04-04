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

module Y2Network
  module SysconfigRoutes
    DEFAULT_ROUTES_FILE = "/etc/sysconfig/network/routes".freeze

      # SCR agent for routes files definition
      def ifroute_term(path)
        raise ArgumentError if path.nil? || path.empty?

        non_empty_str_term = Yast.term(:String, "^ \t\n")
        whitespace_term = Yast.term(:Whitespace)
        optional_whitespace_term = Yast.term(:Optional, whitespace_term)
        routes_content_term = Yast.term(
          :List,
          Yast.term(
            :Tuple,
            Yast.term(
              :destination,
              non_empty_str_term
            ),
            whitespace_term,
            Yast.term(:gateway, non_empty_str_term),
            whitespace_term,
            Yast.term(:netmask, non_empty_str_term),
            optional_whitespace_term,
            Yast.term(
              :Optional,
              Yast.term(:device, non_empty_str_term)
            ),
            optional_whitespace_term,
            Yast.term(
              :Optional,
              Yast.term(
                :extrapara,
                Yast.term(:String, "^\n")
              )
            )
          ),
          "\n"
        )

        Yast.term(
          :ag_anyagent,
          Yast.term(
            :Description,
            Yast.term(:File, path),
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
