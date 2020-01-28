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

require "cwm/dialog"
require "y2network/s390_device_activator"
require "y2network/widgets/s390_common"
require "y2network/widgets/s390_channels"
require "y2network/sysconfig/interfaces_reader"

Yast.import "Lan"

module Y2Network
  module Dialogs
    # Base class dialog for activating S390 devices
    class S390DeviceActivation < CWM::Dialog
      # @param builder [Y2Network::InterfaceConfigBuilder]
      # @return [S390DeviceActivation, nil]
      def self.for(builder)
        return nil unless builder.type

        case builder.type.short_name
        # Both interfaces uses the qeth driver and uses the same configuration
        # for activating the group device.
        when "qeth", "hsi"
          require "y2network/dialogs/s390_qeth_activation"
          require "y2network/s390_device_activators/qeth"
          activator = S390DeviceActivators::Qeth.new(builder)
          Y2Network::Dialogs::S390QethActivation.new(activator)
        when "ctc"
          require "y2network/dialogs/s390_ctc_activation"
          require "y2network/s390_device_activators/ctc"
          activator = S390DeviceActivators::Ctc.new(builder)
          Y2Network::Dialogs::S390CtcActivation.new(activator)
        when "lcs"
          require "y2network/dialogs/s390_lcs_activation"
          require "y2network/s390_device_activators/lcs"
          activator = S390DeviceActivators::Lcs.new(builder)
          Y2Network::Dialogs::S390LcsActivation.new(activator)
        end
      end

      attr_reader :builder
      attr_reader :activator

      # Constructor
      #
      # @param activator [Y2Network::S390DeviceActivator]
      def initialize(activator)
        textdomain "network"

        @activator = activator
        @activator.propose!
        @builder = activator.builder
        @builder.newly_added = false
      end

      def title
        _("S/390 Network Card Configuration")
      end

      def contents
        Empty()
      end

      def run
        ret = super
        if ret == :next
          configured = activator.configure
          if configured
            interface_name = activator.configured_interface
            builder.name = interface_name
            add_interface(interface_name)
          end

          # TODO: Refresh the list of interfaces in yast_config. Take into
          # account that the interface in yast_config does not have a name so
          # the builder.interface is probably nil and should be obtained
          # through the busid.
          if !configured || builder.name.empty?
            Yast::Popup.Error(
              _(
                "An error occurred while creating device.\nSee YaST log for details."
              )
            )

            ret = nil
          end
        end

        ret
      end

      def abort_handler
        Yast::Popup.ReallyAbort(true)
      end

    private

      def reader
        @reader ||= Y2Network::Sysconfig::InterfacesReader.new
      end

      def config
        Yast::Lan.yast_config
      end

      def add_interface(name)
        interface = reader.interfaces.by_name(name)
        config.interfaces << interface if interface
      end
    end
  end
end
