require "yast"
require "y2network/config"
require "y2network/interface_config_builder"

Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Br < InterfaceConfigBuilder

      include Yast::Logger

      def initialize
        super(type: "br")
      end

      def already_configured?(devices)
        devices.any? do |device|
          next false if Yast::NetworkInterfaces.devmap(device).nil?
          ![nil, "none"].include?(Yast::NetworkInterfaces.devmap(device)["BOOTPROTO"])
        end
      end

      # @return [Array<Interface>] list of interfaces usable in the bridge
      def bridgeable_interfaces
        interfaces.all.select { |i| bridgeable?(i) }
      end

    private

      def interfaces
        Config.find(:yast).interfaces
      end

      NONBRIDGEABLE_TYPES = ["br", "tun", "usb", "wlan"].freeze
      NONBRIDGEABLE_STARTMODE = ["nfsroot", "ifplugd"].freeze

      # Checks whether an interface can be bridged in particular bridge
      #
      # @param iface [Interface] an interface to be validated as the bridge slave
      def bridgeable?(iface)
        # cannot enslave itself
        # FIXME: this can happen only bcs we silently use LanItems::Items which
        # already contains partially configured bridge when adding
        return false if iface.name == @name
        return true if !iface.configured

        if interfaces.bond_index[iface.name]
          log.debug("Excluding (#{iface.name}) - is bonded")
          return false
        end

        # the iface is already in another bridge
        if interfaces.bridge_index[iface.name] && interfaces.bridge_index[iface.name] != @name
          log.debug("Excluding (#{iface.name}) - already bridged")
          return false
        end

        # exclude interfaces of type unusable for bridge
        if NONBRIDGEABLE_TYPES.include?(iface.type.short_name)
          log.debug("Excluding (#{iface.name}) - is #{iface.type.short_name}")
          return false
        end

        if NONBRIDGEABLE_STARTMODE.include?(iface.startmode)
          log.debug("Excluding (#{iface.name}) - is #{iface.startmode}")
          return false
        end

        true
      end
    end
  end
end
