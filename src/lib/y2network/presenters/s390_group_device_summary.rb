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

Yast.import "Summary"
Yast.import "HTML"

module Y2Network
  module Presenters
    # This class converts a connection config configuration object into a string to be used
    # in an AutoYaST summary or in a table.
    class S390GroupDeviceSummary
      include Yast::I18n
      include InterfaceStatus

      # @return [String]
      attr_reader :name

      # Constructor
      #
      # @param name [String] name of device to describe
      # @param config [Y2Network::Config]
      def initialize(name, config)
        textdomain "network"
        @name = name
        @config = config
      end

      def text
        device = @config.s390_devices.by_id(@name)
        hardware = device.hardware
        descr = hardware ? hardware.description : ""

        rich = Yast::HTML.Bold(descr) + "<br>"
        rich << "<b>ID: </b>" << device.id << "<br>"
        rich << "<b>Type: </b>" << device.type.short_name << "<br><br>"

        rich << "<p>"
        rich << _("The device is not enable. Press <b>Edit</b>\nto enable it.\n")
        rich << "</p>"

        rich
      end
    end
  end
end
