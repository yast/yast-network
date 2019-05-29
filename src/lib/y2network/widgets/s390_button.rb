require "cwm/common_widgets"

module Y2Network
  module Widgets
    class S390Button < CWM::PushButton
      def initialize
        textdomain "network"
      end

      def label
        _("&S/390")
      end

      def handle
        # return symbol for sequencer
        :s390
      end
    end
  end
end
