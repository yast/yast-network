require "yast"
require "cwm/common_widgets"

Yast.import "IP"
Yast.import "Netmask"
Yast.import "Popup"

module Y2Network
  module Widgets
    class Netmask < CWM::InputField
      def initialize(settings)
        textdomain "network"

        @settings = settings
      end

      def label
        _("&Subnet Mask")
      end

      def help
        # TODO: write it
        ""
      end

      def opt
        [:hstretch]
      end

      def init
        self.value = if @settings["PREFIXLEN"] && !@settings["PREFIXLEN"].empty?
          "/#{@settings["PREFIXLEN"]}"
        else
          @settings["NETMASK"] || ""
        end
      end

      def store
        mask = value
        if mask.start_with?("/")
          @settings["PREFIXLEN"] = mask[1..-1]
        else
          param = Yast::Netmask.Check6(mask) ? "PREFIXLEN" : "NETMASK"
          @settings[param] = mask
        end
      end

      def validate
        return true if valid_netmask

        Yast::Popup.Error(_("No valid netmask or prefix length."))
        focus
        false
      end

      def valid_netmask
        mask = value
        mask = mask[1..-1] if mask.start_with?("/")

        if Yast::Netmask.Check4(mask) || Yast::Netmask.CheckPrefix4(mask) || Yast::Netmask.Check6(mask)
          return true
        end

        false
      end
    end
  end
end
