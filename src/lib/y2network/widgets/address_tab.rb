require "yast"
require "cwm/tabs"

# used widgets
require "y2network/widgets/additional_addresses"
require "y2network/widgets/boot_protocol"
require "y2network/widgets/ip_address"
require "y2network/widgets/netmask"
require "y2network/widgets/remote_ip"
require "y2network/widgets/tunnel"
require "y2network/widgets/vlan_id"
require "y2network/widgets/vlan_interface"

module Y2Network
  module Widgets
    class AddressTab < CWM::Tab
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Address")
      end

      def contents
        type = @settings.type

        drvtype = driver_type(type)
        # TODO: check if this kind of device is still valid and used
        is_ptp = drvtype == "ctc" || drvtype == "iucv"
        # TODO: dynamic for dummy. or add dummy from outside?
        no_dhcp =
          is_ptp ||
          type == "dummy"

        address_p2p_contents = Frame(
          "", # labelless frame
          VBox(IPAddress.new(@settings), RemoteIP.new(@settings))
        )

        address_static_contents = Frame(
          "", # labelless frame
          VBox(
            IPAddress.new(@settings),
            Netmask.new(@settings),
            # TODO: new widget, add logic
            # "GATEWAY"
            Empty()
          )
        )

        address_dhcp_contents = VBox(BootProtocol.new(@settings))
        just_address_contents = if is_ptp
          address_p2p_contents
        elsif no_dhcp
          address_static_contents
        else
          address_dhcp_contents
        end

        label = HBox(
          type == "vlan" ? VBox(HBox(VlanInterface.new(@settings), VlanID.new(@settings))) : Empty()
        )

        address_contents = if ["tun", "tap"].include?(type)
          # TODO: move it to own tab or general as it does not fit here
          VBox(Left(label), Tunnel.new(@settings))
        else
          VBox(
            Left(label),
            just_address_contents,
            AdditionalAddresses.new(@settings)
          )
        end

        address_contents
      end

      # For s390 hwinfo gives us a multitude of types but some are handled
      # the same, mostly acording to the driver which is used. So let's group
      # them under the name Driver Type.
      # TODO: move outside
      # @param [String] type a type, as in Lan::type
      # @return driver type, like formerly type2 for s390
      def driver_type(type)
        drvtype = type
        # handle HSI like qeth, bsc#55692 #c15
        if type == "hsi"
          drvtype = "qeth"
        # Should eth occur on s390?
        elsif type == "tr" || type == "eth"
          drvtype = "lcs"
        # N#82891
        elsif type == "escon" || type == "ficon"
          drvtype = "ctc"
        end
        drvtype
      end
    end
  end
end
