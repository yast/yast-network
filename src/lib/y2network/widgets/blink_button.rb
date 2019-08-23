# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "cwm/custom_widget"
require "y2network/widgets/slave_items"
require "shellwords"

Yast.import "UI"

module Y2Network
  module Widgets
    class BlinkButton < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def contents
        Frame(
          _("Show Visible Port Identification"),
          HBox(
            # translators: how many seconds will card be blinking
            IntField(
              Id(:blink_time),
              _("Seconds") + ":",
              0,
              100,
              5
            ),
            PushButton(Id(:blink_button), _("Blink"))
          )
        )
      end

      def handle
        device = @settings["IFCFG"]
        timeout = Yast::UI.QueryWidget(:blink_time, :Value)
        log.info "blink, blink ... #{timeout} seconds on #{device} device"
        cmd = "/usr/sbin/ethtool -p #{device.shellescape} #{timeout.to_i}"
        res = Yast::SCR.Execute(Yast::Path.new(".target.bash_output"), cmd)
        log.info "#{cmd} : #{res}"

        nil
      end

      def help
        _(
          "<p><b>Show visible port identification</b> allows you to physically identify now configured NIC. \n" \
            "Set appropriate time, click <b>Blink</b> and LED diodes on you NIC will start blinking for selected time.\n" \
            "</p>"
        )
      end
    end
  end
end
