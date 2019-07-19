require "yast"
require "y2network/config"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    class Bonding < InterfaceConfigBuilder
      include Yast::Logger

      def initialize
        super(type: InterfaceType::BONDING)

        # fill mandatory bond option
        @config["BOND_SLAVES"] = []
      end

      # @return [Array<Interface>] list of interfaces usable for the bond device
      def bondable_interfaces
        interfaces.all.select { |i| bondable?(i) }
      end

      # @return [String] options for bonding
      attr_writer :bond_options
      # current options for bonding
      def bond_options
        return @bond_options if @bond_options

        @bond_options = Yast::LanItems.bond_option
        if @bond_options.nil? || @bond_options.empty?
          @bond_options = @config["BONDING_MODULE_OPTS"]
        end
        @bond_options
      end

      # (see Y2Network::InterfaceConfigBuilder#save)
      def save
        super

        Yast::LanItems.bond_slaves = @config["BOND_SLAVES"]
        Yast::LanItems.bond_option = bond_options
      end

    private

      def interfaces
        Config.find(:yast).interfaces
      end

      # Checks whether an interface can be enslaved in particular bond interface
      #
      # @param iface [Interface] an interface to be validated as bond_iface slave
      # TODO: Check for valid configurations. E.g. bond device over vlan
      # is nonsense and is not supported by netconfig.
      # Also devices enslaved in a bridge should be excluded too.
      def bondable?(iface)
        Yast.import "Arch"
        Yast.include self, "network/lan/s390.rb"

        # check if the device is L2 capable on s390
        if Yast::Arch.s390
          s390_config = s390_ReadQethConfig(iface.name)

          # only devices with L2 support can be enslaved in bond. See bnc#719881
          return false unless s390_config["QETH_LAYER2"] == "yes"
        end

        if interfaces.bond_index[iface.name] && interfaces.bond_index[iface.name] != @name
          log.debug("Excluding (#{iface.name}) - is already bonded")
          return false
        end

        # cannot enslave itself
        # FIXME: this can happen only bcs we silently use LanItems::Items which
        # already contains partially configured bond when adding
        return false if iface.name == @name

        return true if !iface.configured

        iface.bootproto == "none"
      end
    end
  end
end
