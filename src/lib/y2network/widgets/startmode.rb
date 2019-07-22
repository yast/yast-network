require "cwm/common_widgets"
require "y2network/startmode"

module Y2Network
  module Widgets
    class Startmode < CWM::ComboBox
      def initialize(config, plug_priority_widget)
        textdomain "network"

        @config = config
        @plug_priority_widget = plug_priority_widget
      end

      def opt
        [:notify]
      end

      def label
        _("Activate &Device")
      end

      def init
        self.value = @config.startmode.name
        handle
      end

      def store
        @config.startmode = value
      end

      def handle
        value == "ifplugd" ? @plug_priority_widget.enable : @plug_priority_widget.disable

        nil
      end

      def help
        # tricky init only to not break long help text translations
        items_help =
          [
            # TRANSLATORS: help text for Device Activation
            _(
              "<p><b>Manually</b>: You control the interface manually\n" \
                "via 'ifup' or 'qinternet' (see 'User Controlled' below).</p>\n"
            ),
            # TRANSLATORS: help text for Device Activation
            _(
              "<b>On Cable Connection</b>:\n" \
                "The interface is watched for whether there is a physical\n" \
                "network connection. That means either the cable is connected or the\n" \
                "wireless interface can connect to an access point.\n"
            ),
            # TRANSLATORS: help text for Device Activation
            _(
              "With <b>On Hotplug</b>,\n" \
                "the interface is set up as soon as it is available. This is\n" \
                "nearly the same as 'At Boot Time', but does not result in an error at\n" \
                "boot time if the interface is not present.\n"
            ),
            # TRANSLATORS: help text for Device Activation
            _(
              "Using <b>On NFSroot</b> is similar to <tt>auto</tt>. Interfaces with this startmode will never\n" \
                "be shut down via <tt>rcnetwork stop</tt>. <tt>ifdown <iface></tt> is still available.\n" \
                "Use this if you have an NFS or iSCSI root filesystem.\n"
            )
          ]

        # Device activation main help. The individual parts will be
        # substituted as %1
        Yast::Builtins.sformat(
          _(
            "<p><b><big>Device Activation</big></b></p> \n" \
              "<p>Choose when to bring up the network interface. <b>At Boot Time</b> activates it during system boot, \n" \
              "<b>Never</b> does not start the device.\n" \
              "%1</p>\n"
          ),
          items_help.join(" ")
        )
      end

      def items
        Y2Network::Startmode.all.map do |mode|
          [mode.to_s, mode.to_human_string]
        end
      end
    end
  end
end
