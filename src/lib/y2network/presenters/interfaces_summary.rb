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
require "y2network/presenters/interface_status"

Yast.import "Summary"
Yast.import "HTML"

module Y2Network
  module Presenters
    # This class converts a connection config configurations into a string to be used
    # in an AutoYaST summary.
    class InterfacesSummary
      include Yast::I18n
      include Yast::Logger
      include InterfaceStatus

      # @return [Config]
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def text
        overview = config.interfaces.map do |interface|
          connection = config.connections.by_name(interface.name)
          descr = interface.hardware ? interface.hardware.description : ""
          descr = interface.name if descr.empty?
          status = connection ? status_info(connection) : Yast::Summary.NotConfigured
          Yast::Summary.Device(descr, status)
        end

        Yast::Summary.DevicesList(overview)
      end
    end
  end
end
