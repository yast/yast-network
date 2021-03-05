# Copyright (c) [2021] SUSE LLC
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
require "cwm"

module Installation
  module Console
    module Plugins
      # define a CWM widget for starting proxy configuration
      class NetworkButton < CWM::PushButton
        def initialize
          textdomain "network"
        end

        def label
          # TRANSLATORS: a button label, it starts the network configuration
          _("Configure Network Devices...")
        end

        def help
          # TRANSLATORS: help text
          _("<p>The <b>Configure Network Devices</b> button starts the network " \
            "configuration module. You can configure your network connection there.</p>")
        end

        def handle
          Yast::WFM.call("inst_lan", [{ "skip_detection" => true }])
          nil
        end
      end

      # define a console plugin
      class NetworkButtonPlugin < MenuPlugin
        def widget
          NetworkButton.new
        end
      end
    end
  end
end
