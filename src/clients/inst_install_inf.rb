require "yast"
require "network/install_inf_convertor"

module Yast

  class InstInstallInfClient < Client
    def main
      InstallInfConvertor.instance.write_netconfig

      :next
    end
  end

end

Yast::InstInstallInfClient.new.main
