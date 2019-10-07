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
require "yast2/execute"

module Y2Network
  # This class is responsable of activating the supported S390 devices.
  class S390DeviceActivator
    extend Forwardable
    include Yast::Logger

    # Command for configuring z Systems specific devices
    CONFIGURE_CMD = "/sbin/chzdev".freeze
    # Command for displaying configuration of z Systems specific devices
    LIST_CMD = "/sbin/lszdev".freeze

    def_delegators :@builder, :type

    attr_accessor :builder

    # Load fresh instace of device activator for given interface config builder
    def self.for(builder)
      type = builder.type
      require "y2network/s390_device_activators/#{type.file_name}"
      S390DeviceActivators.const_get(type.class_name).new(builder)
    rescue LoadError => e
      log.info "Specialized device activator for #{type.short_name} not found. #{e.inspect}"
      nil
    end

    # Constructor
    #
    # @param builder [Y2Network::InterfaceConfigBuilder]
    def initialize(builder)
      @builder = builder
    end

    # Each s390 device type permits a set of attributes to be passed as extra
    # options to the configuration command. This method return a list of each
    # option in the form "attribute=value"
    #
    # @example qeth options
    #   @activator.configure_attributes
    #   #=> ["bridge_role=primary", "layer2=1", "portno=0", "ipa_takeover/enable=1"]
    #
    # @example ctc options
    #   @activator.configure_attributes
    #   #=> ["protocol=1"]
    #
    # @return [Array<String>]
    def configure_attributes
      []
    end

    # The device id to be used by lszdev or chzdev commands
    #
    # @return [String, nil]
    def device_id
      nil
    end

    # Returns the complete device id which contains the given channel
    #
    # @param channel [String]
    # @return [String]
    def device_id_from(channel)
      cmd = [LIST_CMD, type.short_name, "-c", "id", "-n"]

      Yast::Execute.stdout.on_target!(cmd).split("\n").find do |d|
        d.include? channel
      end
    end

    # It tries to enable the interface with the configured device id
    #
    # @return [Boolean] true when enabled
    def configure
      return false unless device_id
      cmd = [CONFIGURE_CMD, type.short_name, device_id, "-e"].concat(configure_attributes)

      log.info("Activating s390 device: #{device_id}")
      Yast::Execute.on_target!(*cmd, allowed_exitstatus: 0..255).zero?
    end

    # Obtains the enabled interface name associated with the device id
    #
    # @return [String] device name
    def configured_interface
      return "" unless device_id
      cmd = [LIST_CMD, device_id, "-c", "names", "-n"]

      Yast::Execute.stdout.on_target!(cmd).chomp
    end

    # Makes a new configuration proposal
    def propose!
    end
  end
end
