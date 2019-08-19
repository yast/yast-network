require "y2network/widgets/path_widget"

module Y2Network
  module Widgets
    class ClientKeyPath < PathWidget
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      def label
        _("Client &Key")
      end

      def help
        "" # TODO: was missing, write something
      end

      def browse_label
        _("Choose a File with Private Key")
      end

      def init
        self.value = @builder.client_key
      end

      def store
        @builder.client_key = value
      end
    end
  end
end
