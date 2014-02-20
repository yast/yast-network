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
    def self.init
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

      @hardware = ReadHardware("netcard")
      Builtins.y2milestone("hardware %1", @hardware)

      # Split network device
      @netdevice = InstallInf["Netdevice"]
      Builtins.y2milestone("InstallInf::netdevice:%1", @netdevice)

      if Mode.autoinst
        # if possible, for temporary installation network use same device
        # with same MAC address (even if devicename changed) (bnc#648270)
        new_devname = LanUdevAuto.GetDevnameByMAC(InstallInf["HWAddr"])

        Builtins.y2milestone("LanUdevAuto::netdevice:%1", new_devname)

        @netdevice = new_devname if !new_devname.empty?
      end

      # Split FQ hostname
      @hostname = InstallInf["Hostname"]
      if !@hostname.empty? && !IP.Check(@hostname)
        split = Hostname.SplitFQ(@hostname)

        # hostname is supposed to be FQDN (http://en.opensuse.org/Linuxrc)
        # so we should not cut off domain name ... anyway remember domain,
        # use it as fallback below, if there is no DNS search domain (#476208)
        @fqdomain = split[1] if split.size > 1
      else
        # do not have numeric hostname, #152218
        @hostname = ""
      end

      # #180821, todo cleanup
      if !@netdevice.empty?
        mod = SCR.Read(Builtins.add(path(".etc.install_inf_alias"), @netdevice)).to_s

        if !mod.empty?
          @module = mod
          options = SCR.Read(Builtins.add(path(".etc.install_inf_options"), mod)).to_s

          @options = options if !options.empty?
        end
      else
        # FIXME: alias = eth0 tulip
        # FIXME: options = ne io=0x200

        # #42203: correctly parse module and options for proposal
        # "eth0 qeth" -> "qeth"
        # FIXME: this only works for a single module
        mod = InstallInf["Alias"]
        @module = DeleteFirstWord(mod) if mod != ""
      end

      true
    end

    def self.DeleteFirstWord(s)
      ret = Builtins.regexpsub(s, "^[^ ]* +(.*)", "\\1")
      ret == nil ? s : ret
    end

    def self.StdoutOf(command)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      Ops.get_string(out, "stdout", "")
    end

    def self.CreateIfcfg
      ifcfg = ""

      # known net devices: `nfs `iscsi `fcoe
      device = NetworkStorage.getDevice(Installation.destdir)
      network_disk = NetworkStorage.isDiskOnNetwork(device)
      Builtins.y2milestone("Network based device: %1", network_disk)

      if network_disk == :iscsi && NetworkStorage.getiBFTDevices.include?(InstallInf["Netdevice"])
        ifcfg << "STARTMODE='nfsroot'\nBOOTPROTO='ibft'\n"
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

          if !InstallInf["IP6"].empty?
            ifcfg << "%s" % "LABEL_ipv6='ipv6'\n"
            ifcfg << "IPADDR_ipv6='%s'\n" % InstallInf["IP6"]
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
            path(".target.bash"),
            "sed -i s/\"DHCLIENT_SET_HOSTNAME=.*\"/'DHCLIENT_SET_HOSTNAME=\"yes\"'/g /etc/sysconfig/network/dhcp"
          )
        end

        ifcfg << "STARTMODE='onboot'\n"
      end

      # wireless devices (bnc#223570)
      if !InstallInf["WlanESSID"].empty?
        ifcfg << "WIRELESS_ESSID='%s'\n" % InstallInf["WlanESSID"]

        case InstallInf["WlanAuth"]
          when "", "psk"
            ifcfg << "WIRELESS_WPA_PSK='%s'\n" % InstallInf["WlanKey"]
            ifcfg << "WIRELESS_AUTH_MODE='psk'\n"

          when "open"
            ifcfg << "WIRELESS_AUTH_MODE='no-encryption'\n"

          when "wep_open", "wep_restricted"
            type = ""
            if InstallInf["WlankeyType"] == "password"
              type = "h:"
            elsif InstallInf["WlankeyType"] == "ascii"
              type = "s:"
            end

            ifcfg << "WIRELESS_AUTH_MODE='%s'\n" % InstallInf["WlanAuth"] == "wep-open" ? "open" : "sharedkey"
            ifcfg << "WIRELESS_DEFAULT_KEY='0'\n"
            ifcfg << "WIRELESS_KEY_0='%s%s'\n" % [type, InstallInf["WlanKey"]]
            ifcfg << "WIRELESS_KEY_LENGTH='%s'\n" % InstallInf["WlanKeyLen"]

            if !InstallInf["WlanKeyType"].empty? && !InstallInf["WlanKey"].empty?
              ifcfg = "WIRELESS_KEY_0='%s:%s'\n" % [
                Builtins.substring(InstallInf["WlanKeyType"], 0, 1),
                InstallInf["WlanKey"]
              ]
            end
        end
      end

      # if available, write MTU
      mtu = InstallInf["IP_MTU"]
      ifcfg << "MTU='%s'\n" % mtu if !mtu.empty?

      # for qeth devices (s390)
      # bnc#578689 - YaST2 should not write the MAC address into ifcfg file
      hwaddr = InstallInf["HWAddr"]
      if Arch.s390
        devtype = NetworkInterfaces.GetType(@netdevice) if !@netdevice.empty?

        Builtins.y2milestone("Interface type: %1", devtype)

        # only some card types need a persistent MAC (bnc#658708)
        sysfs_id = dev_name_to_sysfs_id(@netdevice, @hardware)
        hwaddr = "" if !s390_device_needs_persistent_mac(sysfs_id, @hardware)

        # hsi devices do not support setting hwaddr (bnc #479481)
        hwaddr = "" if devtype == "hsi"

        # set HW address only for qeth set to Layer 2 (bnc #479481)
        hwaddr = "" if devtype == "eth" && InstallInf["QETH_LAYER2_SUPPORT"] != "1"
      end

      ifcfg << "LLADDR='%s'\n" % hwaddr if Arch.s390 && !hwaddr.empty?

      # point to point interface
      remote_ip = InstallInf["Pointopoint"]
      ifcfg << "REMOTE_IPADDR='%s'\n" % remote_ip if !remote_ip.empty?

      device_name = @netdevice
      if !LanUdevAuto.AllowUdevModify
        # bnc#821427: use same options as in /lib/udev/rules.d/71-biosdevname.rules
        cmd = "biosdevname --policy physical --smbios 2.6 --nopirq -i %s" % @netdevice
        out = String.FirstChunk(StdoutOf(cmd), "\n")
        if !out.empty?
          device_name = out
          Builtins.y2milestone("biosdevname renames #{@netdevice} to #{device_name}")
        end
      end

      ifcfg_name = "ifcfg-%s" % device_name

      hw_name = BuildDescription(
        NetworkInterfaces.device_type(@netdevice),
        NetworkInterfaces.device_num(ifcfg_name),
        { "dev_name" => @netdevice },
        @hardware
      )
      # protect special characters, #305343
      ifcfg << "NAME='%s'\n" % String.Quote(hw_name) if !hw_name.empty?

      Builtins.y2milestone(
        "Network Configuration:\n%1",
        ifcfg
      )

      # write only if file doesn't exists
      dev_file = Builtins.sformat("/etc/sysconfig/network/%1", ifcfg_name)

      SCR.Write(path(".target.string"), dev_file, ifcfg)
      Builtins.y2milestone("ifcfg file: %1", dev_file)

      nil
    end

    # create all network files except ifcfg and hwcfg
    # directly to installed system

    def self.CreateOtherNetworkFiles
      # create hostname
      if !@hostname.empty?
        Builtins.y2milestone(
          "Write HOSTNAME: %1",
          @hostname
        )
        SCR.Write(path(".target.string"), "/etc/HOSTNAME", @hostname)
      end

      if InstallInf["NetConfig"] == "static"
        # create routes file
        if !InstallInf["Gateway"].empty?
          Builtins.y2milestone(
            "Writing route : %1",
            InstallInf["Gateway"]
          )
          SCR.Write(
            path(".target.string"),
            "/etc/sysconfig/network/routes",
            "default %s - -\n" % InstallInf["Gateway"]
          )
        elsif InstallInf["Pointopoint"]
          Builtins.y2milestone(
            "Writing Peer-to-Peer route: %1",
            InstallInf["Pointopoint"]
          )
          SCR.Write(
            path(".target.string"),
            "/etc/sysconfig/network/routes",
            "default %s - -\n" % InstallInf["Pointopoint"]
          )
        else
          Builtins.y2warning("No routing information in install.inf")
        end

        # write DHCPTimeout linuxrc parameter as /etc/sysconfig/network/config.WAIT_FOR_INTERFACES (bnc#396824)
        if InstallInf["DHCPTimeout"]
          SCR.Write(
            path(".sysconfig.network.config.WAIT_FOR_INTERFACES"),
            InstallInf["DHCPTimeout"]
          )
          Builtins.y2milestone(
            "Writing WAIT_FOR_INTERFACES=%1",
            InstallInf["DHCPTimeout"]
          )
        end

        # create resolv.conf only for static configuration
        if InstallInf["Nameserver"]
          serverlist = InstallInf["Nameserver"]
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
          elsif !@fqdomain.empty?
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
              @fqdomain
            )
            Builtins.y2milestone(
              "No DNS search domain defined, using FQ domain name %1 as a fallback",
              @fqdomain
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
          path(".target.bash_output"),
          "sed -i s/^WAIT_FOR_INTERFACES=.*/WAIT_FOR_INTERFACES=%s/g /etc/sysconfig/network/config" % connect_wait
        )
      end

      nil
    end

  end
end

if Yast::InstInstallInfClient.init
  Yast::InstInstallInfClient.CreateIfcfg
  Yast::InstInstallInfClient.CreateOtherNetworkFiles
end

:next
