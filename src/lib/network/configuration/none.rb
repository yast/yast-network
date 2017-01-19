require "network/configuration/base"

require "yast"

Yast.import "NetworkInterfaces"

module Network
  module Configuration
    class None < Base
      def save
        dev_id = Yast::NetworkInterfaces.Delete(device.name)
        Yast::NetworkInterfaces.Commit
        Yast::NetworkInterfaces.Write(device.name) #write only this device
      end
    end
  end
end
