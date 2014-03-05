Yast.import "LanItems"
Yast.import "NetworkInterfaces"

#enclose client into own namespace to prevent messing global namespace
module SetupDHCPClient
  include Yast

  BASH_PATH = Path.new(".target.bash")
  BASH_OUT_PATH = Path.new(".target.bash_output")

  def self.network_cards
    LanItems.Read
    LanItems.GetNetcardNames
  end

  # Makes DHCP setup persistent
  #
  # instsys currently uses wicked as network services "manager" (including
  # dhcp client). wicked is currently able to configure a card for dhcp leases
  # only via loading config from file. All other ways are workarounds and
  # needn't to work when wickedd* services are already running
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

  def self.reload_config(card)
    SCR.Execute(BASH_PATH, "wicked ifreload '#{card}'") == 0
  end

  def self.delete_config(devname)
    NetworkInterfaces.Delete2(devname)
  end

  def self.write_configuration
    NetworkInterfaces.Write("")
  end

  def self.activate_changes(devnames)
    return false if !write_configuration

    devnames.map { |d| reload_config(d) }
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

  # Checks if given device is active
  #
  # inactive device <=> a device which is not reported as "up" by wicked
  def self.inactive_config?(devname)
    wicked_query = "wicked ifstatus --brief #{devname} | grep -v 'up$'"
    ret = SCR.Execute(BASH_OUT_PATH, wicked_query)["stdout"].to_s

    return false if ret.empty?

    ret.split(/\s+/, 2).first
  end

  include Logger

  dhcp_cards = network_cards.select { |c| !configured?(c) }
  log.info "Candidates for enabling DHCP: #{dhcp_cards}"

  # TODO time consuming, some progress would be nice
  dhcp_cards.each { |d| setup_dhcp(d) } 

  activate_changes(dhcp_cards)

  # drop devices without dhcp lease
  inactive_devices = dhcp_cards.select { |c| inactive_config?(c) }
  log.info "Inactive devices: #{inactive_devices}"

  inactive_devices.each { |c| delete_config(c) }
  activate_changes(inactive_devices)
end

:next
