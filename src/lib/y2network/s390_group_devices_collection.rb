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
require "y2network/s390_group_device"
require "y2network/can_be_copied"
require "forwardable"
require "yast2/equatable"

module Y2Network
  # A container for network devices.
  #
  # Objects of this class are able to keep a list of s390 group devices and
  # perform simple queries on such a list.
  #
  # @example Finding s390 group device by its id
  #   devices = Y2Network::S390GroupDevicesCollection.new([qeth_700, qeth_800])
  #   devices.by_id("0.0.0700:0.0.0701:0.0.0702") #=> qeth_700
  #
  class S390GroupDevicesCollection
    extend Forwardable
    include Yast::Logger
    include CanBeCopied
    include Yast2::Equatable

    # @return [Array<S390GroupDevice>] List of devices
    attr_reader :devices
    alias_method :to_a, :devices

    eql_attr :devices

    def_delegators :@devices, :each, :push, :<<, :reject!, :map, :flat_map, :any?, :size,
      :select, :find

    # Constructor
    #
    # @param devices [Array<S390GroupDevice>] List of devices
    def initialize(devices = [])
      @devices = devices
    end

    def eql_hash
      h = super
      h[:devices] = h[:devices].sort_by(&:hash) if h.keys.include?(:devices)
      h
    end

    # Returns an s390 group device with the given id if present
    #
    # @param id [String] s390 group device id ("eth0", "br1", ...)
    # @return [S390GroupDevice,nil] S390GroupDevice with the given id or nil if not found
    def by_id(id)
      devices.find { |device| device.id == id }
    end

    # Returns list of devices of given type
    #
    # @param type [String] device type
    # @return [S390GroupDevicesCollection] list of found devices
    def by_type(type)
      S390GroupDevicesCollection.new(devices.select { |d| d.type.short_name == type })
    end

    # Deletes elements which meet a given condition
    #
    # @return [S390GroupDevicesCollection]
    def delete_if(&block)
      devices.delete_if(&block)
      self
    end
  end
end
