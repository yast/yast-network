# Copyright (c) [2020] SUSE LLC
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
require "yast2/execute"
require "y2network/interface_type"
require "y2network/hwinfo"

module Y2Network
  # This class represents z Systems network devices which requires the use of
  # multiple I/O subchannels as 'QETH', 'CTC' and 'LCS' devices.
  class S390GroupDevice
    include Yast::Logger

    # Command for configuring z Systems specific devices
    CONFIGURE_CMD = "/sbin/chzdev".freeze
    # Command for displaying configuration of z Systems specific devices
    LIST_CMD = "/sbin/lszdev".freeze
    SUPPORTED_TYPES = ["qeth", "lcs", "ctc"].freeze

    # @return [Y2Network::InterfaceType]
    attr_accessor :type
    # @return [String] the device id
    attr_accessor :id
    # @return [Y2Network::Interface,nil)
    attr_accessor :interface

    alias_method :name, :id

    # @param type [String]
    # @param id [String]
    # @param interface [String, nil]
    def initialize(type, id, interface = nil)
      @type = Y2Network::InterfaceType.from_short_name(type)
      @id = id
      @interface = interface
    end

    # Obtains the hwinfo associated with the read channel
    def hardware
      Y2Network::Hwinfo.netcards.find { |h| h.busid == id.to_s.split(":").first }
    end

    # Check whether the device is online or not
    def online?
      cmd = [LIST_CMD, id, "-c", "on", "-n"]

      Yast::Execute.stdout.on_target!(cmd).split("\n").first == "yes"
    end

    class << self
      # Returns the list of S390 group devices of the given type
      #
      # @param type [String] s390 group device type (qeth, ctc or lcs)
      # @param offline [Boolean] whether should return only offline devices or
      #   not
      # @return [Array<Y2Network::S390GroupDevice>] list of s390 group devices
      def list(type, offline = true)
        cmd = [LIST_CMD, type, "-c", "id,names", "-n"]
        cmd << "--offline" if offline

        Yast::Execute.locally!(*cmd, stdout: :capture).split("\n").map do |device|
          id, iface_name = device.split(" ")
          new(type, id, iface_name)
        end
      end

      # Convenience method to obtain the all the supported types s390 group
      # devices.
      #
      # @param offline [Boolean] whether should return only offline devices or
      #   not
      # @return [Array<Y2Network::S390GroupDevice>] list of s390 group devices
      def all(offline: false)
        SUPPORTED_TYPES.map { |t| list(t, offline) }.flatten
      end

      # Convenience method to obtain the all the offline s390 network group
      # devices.
      def offline
        all(offline: true)
      end
    end
  end
end
