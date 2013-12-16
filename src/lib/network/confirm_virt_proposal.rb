# encoding: utf-8

require 'yast'

module Yast

  Yast.import "UI"
  Yast.import "LanItems"
  Yast.import "Popup"

  # The class represents a simple dialog which asks user for confirmation of
  # network.service restart during installation.
  class ConfirmVirtProposal

    include UIShortcuts
    include I18n

    def self.run
      open

      # for autoinstallation popup has timeout 10 seconds (#192181)
      # timeout for every case (bnc#429562)
      ret = UI.TimeoutUserInput(10 * 1000)

      close

      ret
    end

  private

    def self.open
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          HCenter(
            HSquash(
              VBox(
                HCenter(
                  HSquash(
                    VBox(
                      # This is the heading of the popup box
                      Left(Heading(_("Confirm Network Restart"))),
                      VSpacing(0.5),
                      # This is in information message. Next come the
                      # hardware class name (network cards).
                      HVCenter(
                        Label(
                          _(
                            "Because of the bridged network, YaST2 needs to restart the network to apply the settings."
                          )
                        )
                      ),
                      VSpacing(0.5)
                    )
                  )
                ),
                ButtonBox(
                  HWeight(
                    1,
                    PushButton(
                      Id(:ok),
                      Opt(:default, :okButton),
                      Label.OKButton
                    )
                  ),
                  # PushButton label
                  HWeight(
                    1,
                    PushButton(
                      Id(:cancel),
                      Opt(:cancelButton),
                      Label.CancelButton
                    )
                  )
                ),
                VSpacing(0.2)
              )
            )
          ),
          HSpacing(1)
        )
      )

      UI.SetFocus(Id(:ok))
    end

    def self.close
      UI.CloseDialog
    end

  end
end
