require "yast"
require "y2network/interface_config_builder"

module Y2Network
  module InterfaceConfigBuilders
    class Dummy < InterfaceConfigBuilder
      def initialize
        super(type: InterfaceType::DUMMY)
      end

      # It does all operations needed for sucessfull configuration export.
      #
      # In case of config builder for dummy interface type it gurantees that
      # the interface will be recognized as dummy one by the backend properly.
      def save
        super

        @config["INTERFACETYPE"] = "dummy"

        nil
      end
    end
  end
end
