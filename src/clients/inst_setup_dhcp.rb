Yast.import "LanItems"
Yast.import "NetworkInterfaces"

#enclose client into own namespace to prevent messing global namespace
module SetupDHCPClient
  include Yast

  BASH_PATH = Path.new(".target.bash")
  WICKED_BIN_DIR = "/usr/lib/wicked/bin"

  def self.network_cards
    LanItems.Read
    LanItems.GetNetcardNames
  end

  def self.setup_dhcp card
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

  def self.get_lease_ipvx?(v, card)
    SCR.Execute(BASH_PATH, "#{WICKED_BIN_DIR}/wickedd-dhcp#{v} --test '#{card}' | grep ^IPADDR") == 0
  end

  def self.get_lease?(card)
    get_lease_ipvx?(6, card) || get_lease_ipvx?(4, card)
  end

  def self.start_dhcp(card)
    SCR.Execute(BASH_PATH, "dhcpcd '#{card}'") == 0
  end

  def self.write_configuration
    NetworkInterfaces.Write("")
  end

  def self.configured?(devname)
    # TODO:
    # one day there should be LanItems.IsItemConfigured, but we currently
    # miss index -> devname translation. As this LanItems internal structure
    # will be subject of refactoring, we will use NetworkInterfaces directly.
    # It currently doesn't hurt as it currently writes configuration for both
    # wicked even sysconfig.
    NetworkInterfaces.Check(devname)
  end

  include Logger

# TODO time consuming, some progress would be nice
  dhcp_cards = network_cards.select { |c| !configured?(c) && get_lease?(c) }
  log.info "Candidates for enabling DHCP: #{dhcp_cards}"

  dhcp_cards.each do |dcard|
    setup_dhcp(dcard) # make DHCP setup persistent
    start_dhcp(dcard)
  end

  write_configuration
end

:next
