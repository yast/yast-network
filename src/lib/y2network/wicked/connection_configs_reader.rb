# Copyright (c) [2021] SUSE LLC
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
require "cfa/interface_file"
require "y2network/connection_configs_collection"
require "y2network/wicked/connection_config_reader"

module Y2Network
  module Wicked
    # This class reads connection configurations from sysconfig files
    #
    # @see Y2Network::ConnectionConfigsCollection
    class ConnectionConfigsReader
      attr_reader :issues_list

      # @param issues_list [Errors::List] List to register errors
      def initialize(issues_list)
        @issues_list = issues_list
      end

      # Returns the connection configurations from sysconfig
      #
      # It needs the list of known interfaces in order to infer
      # the type of the connection.
      #
      # @param interfaces [Y2Network::InterfacesCollection] Known interfaces
      # @return [Y2Network::ConnectionConfigsCollection]
      def connections(interfaces)
        empty_collection = ConnectionConfigsCollection.new([])
        CFA::InterfaceFile.all.each_with_object(empty_collection) do |file, conns|
          interface = interfaces.by_name(file.interface)
          connection = ConnectionConfigReader.new.read(
            file.interface,
            interface ? interface.type : nil,
            issues_list
          )
          conns << connection if connection
        end
      end
    end
  end
end
