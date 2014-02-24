require "yast"

include Yast
include UIShortcuts
include I18n

module Yast

  BASH_PATH = Path.new(".target.bash")

  class InstallInf
    INSTALL_INF = Path.new(".etc.install_inf")

    def self.[](item)
      SCR.Read(INSTALL_INF + Path.new(".#{item}")).to_s
    end
  end

  class InstInstallInfClient < Client

    include Singleton

    def initialize
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "NetworkInterfaces"
      Yast.import "FileUtils"
      Yast.import "Netmask"
      Yast.import "NetworkStorage"
      Yast.import "Proxy"
      Yast.import "Installation"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "Arch"
      Yast.import "LanUdevAuto"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/complex.rb"
    end

    def CreateIfcfg
      ifcfg = ""

      # known net devices: `nfs `iscsi `fcoe
      device = NetworkStorage.getDevice(Installation.destdir)
      network_disk = NetworkStorage.isDiskOnNetwork(device)
      Builtins.y2milestone("Network based device: %1", network_disk)

      if network_disk == :iscsi && NetworkStorage.getiBFTDevices.include?(InstallInf["Netdevice"])
        ifcfg << "STARTMODE='nfsroot'\n"
        ifcfg << "BOOTPROTO='ibft'\n"
      else
        # set BOOTPROTO=[ static | dhcp ], linuxrc names it "NetConfig"
        bootproto = InstallInf["NetConfig"]
        case bootproto
        when "static"
          # add broadcast interface #suse49131
          ifcfg << "BOOTPROTO='static'\n"
          ifcfg << "IPADDR='%s/%s'\n" % [
            InstallInf["IP"],
            Netmask.ToBits(InstallInf["Netmask"])
          ]
          ifcfg << "BROADCAST='%s'\n" % InstallInf["Broadcast"]

          ip6_addr = InstallInf["IP6"]
          if !ip6_addr.empty?
            ifcfg << "LABEL_ipv6='ipv6'\n"
            ifcfg << "IPADDR_ipv6='#{ip6_addr}'\n"
          end

        when "dhcp"
          ifcfg << "BOOTPROTO='dhcp4'\n"

        when "dhcp6"
          ifcfg << "BOOTPROTO='dhcp6'\n"

        when "dhcp,dhcp6"
          ifcfg << "BOOTPROTO='dhcp'\n"
        end

        # set DHCP_SET_HOSTNAME=yes  #suse30528
        if bootproto =~ /dhcp/
          Builtins.y2milestone("set DHCLIENT_SET_HOSTNAME=yes on installed system")
          SCR.Execute(
            BASH_PATH,
            "sed -i s/\"DHCLIENT_SET_HOSTNAME=.*\"/'DHCLIENT_SET_HOSTNAME=\"yes\"'/g /etc/sysconfig/network/dhcp"
          )
        end

        ifcfg << "STARTMODE='onboot'\n"
      end

      # wireless devices (bnc#223570)
      ifcfg << create_wlan_ifcfg

      # if available, write MTU
      mtu = InstallInf["IP_MTU"]
      ifcfg << "MTU='#{mtu}'\n" if !mtu.empty?

      # for qeth devices (s390)
      # bnc#578689 - YaST2 should not write the MAC address into ifcfg file
      hardware = ReadHardware("netcard")
      Builtins.y2milestone("hardware %1", hardware)

      ifcfg << create_s390_ifcfg(hardware) if Arch.s390

      # point to point interface
      remote_ip = InstallInf["Pointopoint"]
      ifcfg << "REMOTE_IPADDR='#{remote_ip}'\n" if !remote_ip.empty?

      ifcfg << create_device_name_ifcfg(hardware)

      Builtins.y2milestone(
        "Network Configuration:\n%1",
        ifcfg
      )

      ifcfg
    end

    # create all network files except ifcfg and hwcfg
    # directly to installed system

    def CreateOtherNetworkFiles
      # Split FQ hostname
      hostname = InstallInf["Hostname"]
      if !hostname.empty? && !IP.Check(hostname)
        split = Hostname.SplitFQ(hostname)

        # hostname is supposed to be FQDN (http://en.opensuse.org/Linuxrc)
        # so we should not cut off domain name ... anyway remember domain,
        # use it as fallback below, if there is no DNS search domain (#476208)
        fqdomain = split[1] if split.size > 1
      else
        # do not have numeric hostname, #152218
        hostname = ""
      end

      # create hostname
      if !hostname.empty?
        Builtins.y2milestone(
          "Write HOSTNAME: %1",
          hostname
        )
        SCR.Write(path(".target.string"), "/etc/HOSTNAME", hostname)
      end

      gateway = InstallInf["Gateway"]
      ptp =  InstallInf["Pointopoint"]
      if InstallInf["NetConfig"] == "static"
        # create routes file
        if !gateway.empty?
          Builtins.y2milestone(
            "Writing route : %1",
            gateway
          )
          SCR.Write(
            path(".target.string"),
            "/etc/sysconfig/network/routes",
            "default %s - -\n" % gateway
          )
        elsif ptp
          Builtins.y2milestone(
            "Writing Peer-to-Peer route: %1",
            ptp
          )
          SCR.Write(
            path(".target.string"),
            "/etc/sysconfig/network/routes",
            "default %s - -\n" % ptp
          )
        else
          Builtins.y2warning("No routing information in install.inf")
        end

        # write DHCPTimeout linuxrc parameter as /etc/sysconfig/network/config.WAIT_FOR_INTERFACES (bnc#396824)
        dhcp_timeout = InstallInf["DHCPTimeout"]
        if dhcp_timeout
          SCR.Write(
            path(".sysconfig.network.config.WAIT_FOR_INTERFACES"),
            dhcp_timeout
          )
          Builtins.y2milestone(
            "Writing WAIT_FOR_INTERFACES=%1",
            dhcp_timeout
          )
        end

        # create resolv.conf only for static configuration
        nameserver = InstallInf["Nameserver"]
        if nameserver
          serverlist = nameserver
          # write also secondary and third nameserver when available (bnc#446101)
          nameserver2 = InstallInf["Nameserver2"]
          serverlist << " " << nameserver2 if !nameserver2.empty?

          nameserver3 = InstallInf["Nameserver3"]
          serverlist << " " << nameserver3 if !nameserver3.empty?
          #
          #Do not write /etc/resolv.conf directly, feed the data to sysconfig instead,
          #'netconfig' will do the job later on network startup (FaTE #303618)
          SCR.Write(
            path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS"),
            serverlist
          )
          Builtins.y2milestone(
            "Writing static nameserver entry: %1",
            nameserver
          )

          #Enter search domain data only if present
          domain = InstallInf["Domain"]
          if !domain.empty?
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
              domain
            )
            Builtins.y2milestone(
              "Writing static searchlist entry: %1",
              domain
            )
          elsif !fqdomain.empty?
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
              fqdomain
            )
            Builtins.y2milestone(
              "No DNS search domain defined, using FQ domain name %1 as a fallback",
              fqdomain
            )
          end

          #We're done. It is OK not to touch NETCONFIG_DNS_POLICY now as it is set to 'auto' by default
          #and user did not have a chance to modify it up to now
          SCR.Write(path(".sysconfig.network.config"), nil)
        end
      end

      # create proxy sysconfig file
      proxyUrl = InstallInf["ProxyUrl"]
      proxyProto = InstallInf["ProxyProto"].empty?
      if !proxyProto && !proxyUrl.empty?
        Builtins.y2milestone(
          "Writing proxy settings: %1",
          proxyUrl
        )

        Proxy.Read
        ex = Proxy.Export

        # bnc#693640 - update Proxy module's configuration
        # username and password is stored in url because it is handled by linuxrc this way and it is impossible
        # to distinguish how the user inserted it (separate or as a part of url?)
        ex["#{proxyProto}_proxy"] = proxyUrl if ex

        Proxy.Import(ex)
        Proxy.Write

        Builtins.y2debug("Written proxy settings: %1", ex)
      end
      # create defaultdomain
      nisdomain = InstallInf["NISDomain"]
      if !nisdomain.empty? && FileUtils.Exists("/etc/defaultdomain")
        Builtins.y2milestone(
          "Write defaultdomain: %1",
          nisdomain
        )
        SCR.Write(
          path(".target.string"),
          "/etc/defaultdomain",
          nisdomain
        )
      end

      # write wait_for_interfaces if needed
      connect_wait = InstallInf["ConnectWait"]
      if !connect_wait.empty?
        SCR.Execute(
          BASH_PATH,
          "sed -i s/^WAIT_FOR_INTERFACES=.*/WAIT_FOR_INTERFACES=%s/g /etc/sysconfig/network/config" % connect_wait
        )
      end

      nil
    end

    private
    def dev_name
      netdevice = InstallInf["Netdevice"]

      if Mode.autoinst
        # if possible, for temporary installation network use same device
        # with same MAC address (even if devicename changed) (bnc#648270)
        new_devname = LanUdevAuto.GetDevnameByMAC(InstallInf["HWAddr"])

        netdevice = new_devname if !new_devname.empty?
      end

      Builtins.y2milestone("InstInstallInfClient#dev_name:%1", netdevice)
      return netdevice
    end

    def StdoutOf(command)
      SCR.Execute(path(".target.bash_output"), command)["stdout"].to_s
    end

    def create_wlan_ifcfg
      wlan_key = InstallInf["WlanKey"]
      wlan_essid = InstallInf["WlanESSID"]
      wlan_key_type = InstallInf["WlanKeyType"]
      wlan_auth = InstallInf["WlanAuth"]
      wlan_key_len = InstallInf["WlanKeyLen"]

      return "" if wlan_essid.empty?

      ifcfg = "WIRELESS_ESSID='#{wlan_essid}'\n"

      case wlan_auth
        when "", "psk"
          ifcfg << "WIRELESS_WPA_PSK='#{wlan_key}'\n"
          ifcfg << "WIRELESS_AUTH_MODE='psk'\n"

        when "open"
          ifcfg << "WIRELESS_AUTH_MODE='no-encryption'\n"

        when "wep_open", "wep_restricted"
          if wlan_key_type == "password"
            type = "h:"
          elsif wlan_key_type == "ascii"
            type = "s:"
          else
            type = wlan_key_type[0] + ":"
          end

          auth_mode = wlan_auth == "wep-open" ? "open" : "sharedkey"

          ifcfg << "WIRELESS_AUTH_MODE='%s'\n" % wlan_auth_mode
          ifcfg << "WIRELESS_DEFAULT_KEY='0'\n"
          ifcfg << "WIRELESS_KEY_0='#{type}#{wlan_key}'\n"
          ifcfg << "WIRELESS_KEY_LENGTH='#{wlan_key_len}'\n"
      end

      return ifcfg
    end

    def create_s390_ifcfg(hardware)
      hwaddr = InstallInf["HWAddr"]
      return "" if hwaddr.empty?

      netdevice = dev_name
      return "" if netdevice.empty?

      devtype = NetworkInterfaces.GetType(netdevice)

      Builtins.y2milestone("Interface type: %1", devtype)

      # only some card types need a persistent MAC (bnc#658708)
      sysfs_id = dev_name_to_sysfs_id(netdevice, hardware)
      return "" if !s390_device_needs_persistent_mac(sysfs_id, hardware)

      # hsi devices do not support setting hwaddr (bnc #479481)
      return "" if devtype == "hsi"

      # set HW address only for qeth set to Layer 2 (bnc #479481)
      return "" if devtype == "eth" && InstallInf["QETH_LAYER2_SUPPORT"] != "1"

      return "LLADDR='#{hwaddr}'\n"
    end

    def create_device_name_ifcfg(hardware)
      device_name = dev_name

      hw_name = BuildDescription(
        NetworkInterfaces.device_type(device_name),
        NetworkInterfaces.device_num(device_name),
        { "dev_name" => device_name },
        hardware
      )

      return "" if hw_name.empty?

      # protect special characters, #305343
      return "NAME='%s'\n" % String.Quote(hw_name)
    end

    def write_ifcfg(ifcfg)
      device_name = dev_name

      if !LanUdevAuto.AllowUdevModify
        # bnc#821427: use same options as in /lib/udev/rules.d/71-biosdevname.rules
        cmd = "biosdevname --policy physical --smbios 2.6 --nopirq -i %s" % dev_name
        out = String.FirstChunk(StdoutOf(cmd), "\n")
        if !out.empty?
          device_name = out
          Builtins.y2milestone("biosdevname renames #{dev_name} to #{device_name}")
        end
      end

      dev_file = "/etc/sysconfig/network/ifcfg-#{device_name}"

      Builtins.y2milestone("ifcfg file: %1", dev_file)
      SCR.Write(path(".target.string"), dev_file, ifcfg)
    end

  end
end

install_inf_parser = Yast::InstInstallInfClient.instance

install_inf_parser.write_ifcfg(install_inf_parser.CreateIfcfg)
install_inf_parser.CreateOtherNetworkFiles

:next
