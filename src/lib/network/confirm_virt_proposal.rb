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

module Yast
  # The class represents a simple dialog which asks user for confirmation of
  # network.service restart during installation.
  class ConfirmVirtProposal
    include Singleton
    include UIShortcuts
    include I18n

    Yast.import "Popup"
    Yast.import "Label"

    # Shows a confirmation timed dialogue
    #
    # Returns :ok when user agreed, :cancel otherwise
    def run
      textdomain "network"

      ret = Popup.TimedAnyQuestion(
        _("Confirm Network Restart"),
        _(
          "Because of the bridged network, YaST2 needs to " \
          "restart the network to apply the settings."
        ),
        Label.OKButton,
        Label.CancelButton,
        :focus_yes,
        10
      )

      ret ? :ok : :cancel
    end
  end
end
