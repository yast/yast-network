require "y2network/widgets/path_widget"

module Y2Network
  module Widgets
    class ServerCAPath < PathWidget
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      # FIXME: label and help text is wrong, here it is certificate of CA that is used to sign server certificate
      def label
        _("&Server Certificate")
      end

      def help
        "<p>To increase security, it is recommended to configure\n" \
          "a <b>Server Certificate</b>. It is used\n" \
          "to validate the server's authenticity.</p>\n"
      end

      def browse_label
        _("Choose a Certificate")
      end

      def init
        self.value = @builder.ca_cert
      end

      def store
        @builder.ca_cert = value
      end
    end
  end
end
