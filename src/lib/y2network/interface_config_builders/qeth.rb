require "yast"
require "y2network/interface_config_builder"

Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module InterfaceConfigBuilders
    class Qeth < InterfaceConfigBuilder
      extend Forwardable

      def initialize(config: nil)
        super(type: InterfaceType::QETH, config: config)
      end

      def_delegators :@connection_config,
        :read_channel, :read_channel=,
        :write_channel, :write_channel=,
        :data_channel, :data_channel=,
        :layer2, :layer2=,
        :port_number, :port_number=,
        :lladdress, :lladdress=,
        :ipa_takeover, :ipa_takeover=,
        :attributes, :attributes=

      # @return [String]
      def configure_attributes
        @connection_config.attributes.split(" ")
      end

      def device_id
        return if read_channel.to_s.empty?

        [read_channel, write_channel, data_channel].join(":")
      end

      def device_id_from(busid)
        cmd = "/sbin/lszdev qeth -c id -n".split(" ")

        Yast::Execute.stdout.on_target!(cmd).split("\n").find do |d|
          d.include? busid
        end
      end

      def configure
        cmd = "/sbin/chzdev -e qeth #{device_id}".split(" ").concat(configure_attributes)

        Yast::Execute.on_target!(*cmd, allowed_exitstatus: 0..255).zero?
      end

      def configured_interface
        cmd = "/sbin/lszdev #{device_id} -c names -n".split(" ").concat(configure_attributes)

        Yast::Execute.stdout.on_target!(cmd).chomp
      end

      def propose_channels
        id = device_id_from(hwinfo.busid)
        return unless id
        self.read_channel, self.write_channel, self.data_channel = id.split(":")
      end

      def proposal
        propose_channels unless device_id
      end
    end
  end
end
