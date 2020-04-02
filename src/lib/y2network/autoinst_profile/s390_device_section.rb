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

require "y2network/autoinst_profile/section_with_attributes"
module Y2Network
  module AutoinstProfile
    # This class represents an AutoYaST <device> section under <s390-devices>
    #
    #  <device>
    #    <chanids>0.0.0700 0.0.0701 0.0.0702</chanids>
    #    <layer2 config:type="boolean>true</layer2>
    #    <type>qeth</type>
    #  </device>
    #
    # @see S390DevicesSection
    class S390DeviceSection < SectionWithAttributes
      def self.attributes
        [
          { name: :chanids },
          { name: :layer2 },
          { name: :type },
          { name: :portname }, # deprecated
          { name: :protocol },
          { name: :router }
        ]
      end

      define_attr_accessors

      # @!attribute chanids
      #   @return [String] channel device id separated by spaces or colons

      # @!attribute layer2
      #   @return [Boolean] Whether layer2 is enabler or not

      # @!attribute type
      #   @return [String] S390 device type (qeth, ctc, iucv)

      # @!attribute portname
      #   @return [String] QETH portname (deprecated)

      # @!attribute protocol
      #   @return [String]

      # @!attribute router
      #   @return [String] IUCV router/user

      # Clones a network s390 connection config into an AutoYaST s390 device section
      #
      # @param connection_config [Y2Network::ConnectionConfig] Network connection config
      # @return [S390DeviceSection]
      def self.new_from_network(connection_config)
        result = new
        result.init_from_config(connection_config)
        result
      end

      # Creates an instance based on the profile representation used by the AutoYaST modules
      # (array of hashes objects).
      #
      # @param hash [Hash] Networking section from an AutoYaST profile
      # @return [S390DeviceSection]
      def self.new_from_hashes(hash)
        result = new
        result.init_from_hashes(hash)
        result
      end

      # Method used by {.new_from_network} to populate the attributes when cloning a network s390
      # device
      #
      # @param config [Y2Network::ConnectionConfig]
      # @return [Boolean]
      def init_from_config(config)
        @type = config.type.short_name
        case config
        when ConnectionConfig::Qeth
          @chanids = config.device_id
          @layer2 = config.layer2
        when ConnectionConfig::Ctc
          @chanids = config.device_id
          @protocol = config.protocol
        when ConnectionConfig::Lcs
          @chanids = config.device_id
        end

        true
      end

      # Method used by {.new_from_hashes} to populate the attributes when importing a profile
      #
      # @param hash [Hash] see {.new_from_hashes}
      def init_from_hashes(hash)
        super
        self.chanids = normalized_chanids(hash["chanids"]) if hash["chanids"]
      end

    private

      # Normalizes the list of channel IDs
      #
      # It replaces spaces with colons.
      #
      # @return [String]
      def normalized_chanids(ids)
        ids.gsub(/\ +/, ":")
      end
    end
  end
end
