# encoding: utf-8

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
          "Because of the bridged network, YaST2 needs to restart the network to apply the settings."
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
