Yast.import "LanItems"
Yast.import "NetworkInterfaces"

include Yast

BASH_PATH = Path.new(".target.bash")

def network_cards
  LanItems.Read
  LanItems.GetNetcardNames
end

def setup_dhcp card
  index = LanItems.FindDeviceIndex(card)

  if index == -1
    raise "Failed to save configuration for device #{card}"
  end

  LanItems.current = index
  LanItems.SetItem

  #tricky part if ifcfg is not set
  # yes, this code smell and show bad API of LanItems
  if !LanItems.IsCurrentConfigured
    NetworkInterfaces.Add
    current = LanItems.Items[LanItems.current]
    current["ifcfg"] = card
  end

  LanItems.bootproto = "dhcp"
  LanItems.startmode = "auto"

  LanItems.Commit
end

def get_lease?(card)
  SCR.Execute(BASH_PATH, "dhcpcd-test '#{card}'") == 0
end

def start_dhcp(card)
  SCR.Execute(BASH_PATH, "dhcpcd '#{card}'") == 0
end

def write_configuration
  NetworkInterfaces.Write("")
end


# TODO time consuming, some progress would be nice
dhcp_cards = network_cards.select { |c| get_lease?(c) }

dhcp_cards.each do |dcard|
  setup_dhcp(dcard) # make DHCP setup persistent
  start_dhcp(dcard)
end

write_configuration

true
