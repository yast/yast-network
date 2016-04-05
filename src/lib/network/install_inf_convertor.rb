require "yast"
require "uri"

module Yast
  class InstallInfConvertor
    include Singleton
    include Logger
    include Yast # for path shortcuts
    include I18n # for textdomain

    BASH_PATH = Path.new(".target.bash")

    # Class for accessing /etc/install.inf.
    # See http://en.opensuse.org/SDB:Linuxrc_install.inf
    class InstallInf
      INSTALL_INF = Path.new(".etc.install_inf")

      def self.[](item)
        SCR.Read(INSTALL_INF + Path.new(".#{item}")).to_s
      end
    end

    def initialize
      Yast.import "Hostname"
      Yast.import "DNS"
      Yast.import "IP"
      Yast.import "NetworkInterfaces"
      Yast.import "FileUtils"
      Yast.import "Netmask"
      Yast.import "Proxy"
      Yast.import "String"
      Yast.import "Arch"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/complex.rb"
    end

    def write_netconfig
      write_ifcfg(create_ifcfg)
      write_global_netconfig
    end

    # Reports if user asked for using biosdevname pernament device names
    def AllowUdevModify
      /biosdevname=1/ !~ InstallInf["Cmdline"]
    end

  private

    def create_ifcfg
      ifcfg = ""

      # set BOOTPROTO=[ static | dhcp ], linuxrc names it "NetConfig"
      bootproto = InstallInf["NetConfig"]
      case bootproto
      when "static"
        # add broadcast interface #suse49131
        ifcfg << "BOOTPROTO='static'\n"
        ifcfg << "IPADDR='#{InstallInf["IP"]}/#{Netmask.ToBits(InstallInf["Netmask"])}'\n"
        ifcfg << "BROADCAST='#{InstallInf["Broadcast"]}'\n"

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
        log.info("set DHCLIENT_SET_HOSTNAME=yes on installed system")
        SCR.Execute(
          BASH_PATH,
          "sed -i s/\"DHCLIENT_SET_HOSTNAME=.*\"/'DHCLIENT_SET_HOSTNAME=\"yes\"'/g /etc/sysconfig/network/dhcp"
        )
      end

      ifcfg << "STARTMODE='onboot'\n"

      # wireless devices (bnc#223570)
      ifcfg << create_wlan_ifcfg

      # if available, write MTU
      mtu = InstallInf["IP_MTU"]
      ifcfg << "MTU='#{mtu}'\n" if !mtu.empty?

      # for qeth devices (s390)
      # bnc#578689 - YaST2 should not write the MAC address into ifcfg file
      hardware = ReadHardware("netcard")
      log.info("hardware: #{hardware}")

      ifcfg << create_s390_ifcfg(hardware) if Arch.s390

      # point to point interface
      remote_ip = InstallInf["Pointopoint"]
      ifcfg << "REMOTE_IPADDR='#{remote_ip}'\n" if !remote_ip.empty?

      ifcfg << create_device_name_ifcfg(hardware)

      log.info("Network Configuration:\n#{ifcfg}")

      ifcfg
    end

    # create all network files except ifcfg and hwcfg
    # directly to installed system
    def write_global_netconfig
      # create hostname
      write_hostname

      if InstallInf["NetConfig"] == "static"
        write_gateway

        # write DHCPTimeout linuxrc parameter as /etc/sysconfig/network/config.WAIT_FOR_INTERFACES (bnc#396824)
        write_dhcp_timeout

        # create resolv.conf only for static configuration
        write_dns
      end

      # create proxy sysconfig file
      write_proxy

      # create defaultdomain
      write_nis_domain

      # write wait_for_interfaces if needed
      write_connect_wait

      nil
    end

    def write_dhcp_timeout
      dhcp_timeout = InstallInf["DHCPTimeout"].to_s

      return false if dhcp_timeout.empty?

      log.info("Writing WAIT_FOR_INTERFACES=#{dhcp_timeout}")
      SCR.Write(path(".sysconfig.network.config.WAIT_FOR_INTERFACES"), dhcp_timeout)
    end

    def write_gateway
      gateway = InstallInf["Gateway"].to_s
      ptp =  InstallInf["Pointopoint"].to_s

      # create routes file
      if !gateway.empty?
        log.info("Writing route : #{gateway}")
        return SCR.Write(
          path(".target.string"),
          "/etc/sysconfig/network/routes",
          "default #{gateway} - -\n")
      elsif !ptp.empty?
        log.info("Writing Peer-to-Peer route: #{ptp}")
        return SCR.Write(
          path(".target.string"),
          "/etc/sysconfig/network/routes",
          "default #{ptp} - -\n"
        )
      else
        log.warn("No routing information in install.inf")
        return false
      end
    end

    def hostname
      hostname = InstallInf["Hostname"].to_s

      # do not have numeric hostname, #152218
      return "" if hostname.empty? || IP.Check(hostname)
      hostname
    end

    def write_hostname
      return false if hostname.empty?

      log.info("Write HOSTNAME: #{hostname}")
      SCR.Write(path(".target.string"), DNSClass::HOSTNAME_PATH, hostname)
    end

    def write_dns
      nameserver = InstallInf["Nameserver"].to_s

      return false if nameserver.empty?

      # hostname is supposed to be FQDN (http://en.opensuse.org/Linuxrc)
      # remember domain, use it as fallback below, if there is no DNS search
      # domain (#476208)
      split = Hostname.SplitFQ(hostname) if !hostname.empty? && !IP.Check(hostname)
      fqdomain = ""
      fqdomain = split[1].to_s if split

      serverlist = nameserver
      # write also secondary and third nameserver when available (bnc#446101)
      nameserver2 = InstallInf["Nameserver2"].to_s
      serverlist << " " << nameserver2 if !nameserver2.empty?

      nameserver3 = InstallInf["Nameserver3"].to_s
      serverlist << " " << nameserver3 if !nameserver3.empty?

      # Do not write /etc/resolv.conf directly, feed the data to sysconfig instead,
      # 'netconfig' will do the job later on network startup (FaTE #303618)
      SCR.Write(
        path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS"),
        serverlist
      )
      log.info("Writing static nameserver entry: #{nameserver}")

      # Enter search domain data only if present
      domain = InstallInf["Domain"].to_s
      if !domain.empty?
        SCR.Write(
          path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
          domain
        )
        log.info("Writing static searchlist entry: #{domain}")
      elsif !fqdomain.empty?
        SCR.Write(
          path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
          fqdomain
        )
        log.info("No DNS search domain defined, using FQ domain name #{fqdomain} as a fallback")
      end

      # We're done. It is OK not to touch NETCONFIG_DNS_POLICY now as it is set to 'auto' by default
      # and user did not have a chance to modify it up to now
      SCR.Write(path(".sysconfig.network.config"), nil)
    end

    def write_proxy
      # ProxyURL format: scheme://user:password@server:port
      proxyUrl = InstallInf["ProxyURL"].to_s

      return false if proxyUrl.empty?

      Proxy.Read
      ex = Proxy.Export

      proxy = URI(proxyUrl)
      proxyProto = proxy.scheme

      # save user name and password separately
      ex["proxy_user"] = proxy.user
      proxy.user = nil
      ex["proxy_password"] = proxy.password
      proxy.password = nil
      ex["#{proxyProto}_proxy"] = proxy.to_s
      ex["enabled"] = true
      log.info "Writing proxy settings: #{proxyProto}_proxy = '#{proxy}'"
      log.debug "Writing proxy settings: #{ex}"

      Proxy.Import(ex)
      Proxy.Write
    end

    def write_nis_domain
      nisdomain = InstallInf["NISDomain"].to_s

      return false if nisdomain.empty? || !FileUtils.Exists("/etc/defaultdomain")

      log.info("Write defaultdomain: #{nisdomain}")
      SCR.Write(path(".target.string"), "/etc/defaultdomain", nisdomain)
    end

    def write_connect_wait
      connect_wait = InstallInf["ConnectWait"].to_s

      return false if connect_wait.empty?

      ret = SCR.Execute(
        BASH_PATH,
        "sed -i s/^WAIT_FOR_INTERFACES=.*/WAIT_FOR_INTERFACES=#{connect_wait}/g /etc/sysconfig/network/config"
      )

      ret == 0
    end

    def dev_name
      netdevice = InstallInf["Netdevice"].to_s

      log.info("InstInstallInfClient#dev_name:#{netdevice}")

      netdevice
    end

    def stdout_of(command)
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

        wlan_auth_mode = wlan_auth == "wep-open" ? "open" : "sharedkey"

        ifcfg << "WIRELESS_AUTH_MODE='#{wlan_auth_mode}'\n"
        ifcfg << "WIRELESS_DEFAULT_KEY='0'\n"
        ifcfg << "WIRELESS_KEY_0='#{type}#{wlan_key}'\n"
        ifcfg << "WIRELESS_KEY_LENGTH='#{wlan_key_len}'\n"
      end

      ifcfg
    end

    def create_s390_ifcfg(hardware)
      hwaddr = InstallInf["OSAHWAddr"]
      return "" if hwaddr.empty?

      netdevice = dev_name
      return "" if netdevice.empty?

      devtype = NetworkInterfaces.GetType(netdevice)

      log.info("Interface type: #{devtype}")

      # only some card types need a persistent MAC (bnc#658708)
      sysfs_id = dev_name_to_sysfs_id(netdevice, hardware)
      return "" if !s390_device_needs_persistent_mac(sysfs_id, hardware)

      # hsi devices do not support setting hwaddr (bnc #479481)
      return "" if devtype == "hsi"

      # set HW address only for qeth set to Layer 2 (bnc #479481)
      return "" if devtype == "eth" && InstallInf["Layer2"] != "1"

      "LLADDR='#{hwaddr}'\n"
    end

    def create_device_name_ifcfg(hardware)
      device_name = dev_name

      # authoritative sources of device name are:
      # - hwinfo
      # - install.inf
      # nobody else was able to edit device name so far (so ifcfg["NAME"])
      # is empty
      hw_name = HardwareName(hardware, device_name)
      hw_name = InstallInf["NetCardName"] || "" if hw_name.empty?

      return "" if hw_name.empty?

      # protect special characters, #305343
      "NAME='#{String.Quote(hw_name)}'\n"
    end

    def write_ifcfg(ifcfg)
      device_name = dev_name

      return false if device_name.empty?

      if !AllowUdevModify()
        # bnc#821427: use same options as in /lib/udev/rules.d/71-biosdevname.rules
        cmd = "biosdevname --policy physical --smbios 2.6 --nopirq -i #{dev_name}"
        out = String.FirstChunk(stdout_of(cmd), "\n")
        if !out.empty?
          device_name = out
          log.info("biosdevname renames #{dev_name} to #{device_name}")
        end
      end

      dev_file = "/etc/sysconfig/network/ifcfg-#{device_name}"

      log.info("ifcfg file: #{dev_file}")
      SCR.Write(path(".target.string"), dev_file, ifcfg)
    end
  end
end
