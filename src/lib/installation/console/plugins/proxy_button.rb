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
      # define a CWM widget for starting network configuration
      class ProxyButton < CWM::PushButton
        def initialize
          textdomain "installation"
        end

        def label
          # TRANSLATORS: a button label, it starts the proxy configuration
          _("Configure Network Proxy...")
        end

        def help
          # TRANSLATORS: help text
          _("<p>Use the <b>Configure Network Proxy</b> button if you need " \
            "a proxy for accessing the Internet servers.</p>")
        end

        def handle
          Yast::WFM.call("proxy")
          nil
        end
      end

      # define a console plugin
      class ProxyButtonPlugin < MenuPlugin
        def widget
          ProxyButton.new
        end
      end
    end
  end
end
