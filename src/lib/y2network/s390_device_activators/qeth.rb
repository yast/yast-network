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

require "y2network/s390_device_activator"

module Y2Network
  module S390DeviceActivators
    # This class is responsible of activating OSA-Express (QDIO) and
    # HiperSockets group devices (qeth driver).
    class Qeth < S390DeviceActivator
      def_delegators :@builder,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :data_channel, :data_channel=,
        :layer2, :port_number, :ipa_takeover,
        :hwinfo, :attributes, :device_id

      # Return a list of the options to be set when activating the device. The
      # list is composed by the attributes configured and the attributes that
      # have their own variable (layer2, port_number and ipa_takeover).
      #
      # @example Qeth configuration
      #   activator.layer2 #=> true
      #   activator.port_number #=> 1
      #   activator.ipa_takeover #=> true
      #   activator.attributes #=> "bridge_role=secondary"
      #   activator.configure_attributes #=> ["bridge_role=secondary",
      #     "ipa_takeover/enable=1", "layer2=1", "portno=1"]
      #
      # @see [S390DeviceActivator#configure_attributes]
      def configure_attributes
        extra_attributes = []
        extra_attributes.concat(attributes.split(" ")) if attributes
        # Only set if enable
        extra_attributes << ipa_takeover_attribute if ipa_takeover
        # Only set if enable
        extra_attributes << layer2_attribute if layer2
        extra_attributes << port_attribute if port_number.to_s != "0"
        extra_attributes
      end

      # Modifies the read, write and data channel from the the device id
      def propose_channels
        id = device_id_from(hwinfo.busid)
        return unless id

        self.read_channel, self.write_channel, self.data_channel = id.split(":")
      end

      def propose!
        propose_channels unless device_id
      end

    private

      # Convenience method to obtain the layer2 attribute for the configuration
      # command
      #
      # @return [String]
      def layer2_attribute
        "layer2=#{layer2 ? 1 : 0}"
      end

      # Convenience method to obtain the port number attribute for the
      # configuration command
      #
      # @return [String]
      def port_attribute
        "portno=#{port_number}"
      end

      # Convenience method to obtain the port number attribute for the
      # configuration command
      #
      # @return [String]
      def ipa_takeover_attribute
        "ipa_takeover/enable=#{ipa_takeover ? 1 : 0}"
      end
    end
  end
end
