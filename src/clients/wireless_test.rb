require "yast"
require "y2network/dialogs/wireless"
require "y2network/interface_config_builder"

module Yast
  class Wireless < Client
    def main
      Yast.import "UI"
      textdomain "network"
      Yast.import "Lan"
      Yast.import "NetworkService"

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("routing")
      Wizard.SetNextButton(:next, Label.FinishButton)

      Lan.Read(:cache)
      config = Lan.yast_config.copy
      interface = LanItems.find_type_ifaces("wlan").first

      if interface
        LanItems.FindAndSelect(interface)
        connection_config = config.connections.by_name(LanItems.GetCurrentName)
        builder = Y2Network::InterfaceConfigBuilder.for(LanItems.GetCurrentType(), config: connection_config)
        builder.name = LanItems.GetCurrentName()
        LanItems.SetItem(builder: builder)
        Y2Network::Dialogs::Wireless.run(builder)
      else
        Yast::Popup.Error("No interface to configure")
      end

      UI.CloseDialog
    end
  end
end

Yast::Wireless.new.main
