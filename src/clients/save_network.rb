# encoding: utf-8

#***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
#**************************************************************************
# File:	clients/save_network.ycp
# Package:	Network configuration
# Summary:	Installation routines
# Authors:	Michal Zugec <mzugec@suse.cz>
#
#
module Yast
  class SaveNetworkClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

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

      @InstallInf = {}

      # global variable because chrooted environment
      @network_disk = :no # `nfs `iscsi `fcoe
      @netdevice = ""

      @hardware = ReadHardware("netcard")
      Builtins.y2milestone("hardware %1", @hardware)

      # for update system don't copy network from inst_sys (#325738)
      if !Mode.update
        save_network
      else
        Builtins.y2milestone("update - skip save_network")
      end 
      # EOF

      nil
    end

    # Read one install.inf item
    # @param [String] item InstallInf map key
    # @param [String] var install.inf SCR variable
    # @return true on success
    def ReadInstallInfItem(install_inf, item, var)
      return false if item == nil || item == "" || var == nil || var == ""

      val = Convert.to_string(SCR.Read(Builtins.add(install_inf, var)))
      return false if val == nil

      Ops.set(@InstallInf, item, val) if val != ""

      true
    end

    def DeleteFirstWord(s)
      ret = Builtins.regexpsub(s, "^[^ ]* +(.*)", "\\1")
      ret == nil ? s : ret
    end

    # Read install.inf from the correct location
    # @return true on success
    def ReadInstallInf
      Builtins.y2milestone("ReadInstallInf()")

      # Detect install.inf location
      install_inf = nil
      if Ops.greater_than(SCR.Read(path(".target.size"), "/etc/install.inf"), 0)
        install_inf = path(".etc.install_inf")
        Ops.set(@InstallInf, "installation", "yes")
      else
        # FIXME
        # else if(SCR::Read(.target.size,"/var/lib/YaST2/install.inf") > 0)
        # 	install_inf = .var.lib.YaST2.install_inf;
        return false
      end

      # Read install.inf items
      ReadInstallInfItem(install_inf, "firststage_network", "ConfigureNetwork")
      ReadInstallInfItem(install_inf, "ipaddr", "IP")
      ReadInstallInfItem(install_inf, "ipaddr6", "IP6")
      ReadInstallInfItem(install_inf, "netmask", "Netmask")
      ReadInstallInfItem(install_inf, "bcast", "Broadcast")
      ReadInstallInfItem(install_inf, "remote_ip", "Pointopoint")
      ReadInstallInfItem(install_inf, "mtu", "IP_MTU")
      ReadInstallInfItem(install_inf, "bootproto", "NetConfig")
      ReadInstallInfItem(install_inf, "netdevice", "Netdevice")
      ReadInstallInfItem(install_inf, "gateway", "Gateway")
      ReadInstallInfItem(install_inf, "nameserver", "Nameserver")
      ReadInstallInfItem(install_inf, "nameserver2", "Nameserver2")
      ReadInstallInfItem(install_inf, "nameserver3", "Nameserver3")
      ReadInstallInfItem(install_inf, "domain", "Domain")
      ReadInstallInfItem(install_inf, "nisdomain", "NISDomain")
      ReadInstallInfItem(install_inf, "hostname", "Hostname")
      ReadInstallInfItem(install_inf, "module", "Alias")
      ReadInstallInfItem(install_inf, "proxyUrl", "ProxyUrl")
      ReadInstallInfItem(install_inf, "proxyProto", "ProxyProto")
      #    ReadInstallInfItem(install_inf, "options", "Options");
      # OSAHwAddr parameter s390
      ReadInstallInfItem(install_inf, "hwaddr", "HWAddr")
      ReadInstallInfItem(install_inf, "ethtool_options", "ethtool")
      ReadInstallInfItem(install_inf, "unique", "NetUniqueID")
      ReadInstallInfItem(install_inf, "connect_wait", "ConnectWait")

      ReadInstallInfItem(install_inf, "QETH_LAYER2_SUPPORT", "Layer2")
      #    ReadInstallInfItem(install_inf, "LLADDR", "OSAHWAddr");
      ReadInstallInfItem(install_inf, "dhcptimeout", "DHCPTimeout")

      ReadInstallInfItem(install_inf, "WESSID", "WlanESSID")
      ReadInstallInfItem(install_inf, "WAuth", "WlanAuth")
      ReadInstallInfItem(install_inf, "WKey", "WlanKey")
      ReadInstallInfItem(install_inf, "WkeyType", "WlanKeyType")
      ReadInstallInfItem(install_inf, "WkeyLen", "WlanKeyLen")


      # Split network device
      @netdevice = Ops.get_string(@InstallInf, "netdevice", "")
      Builtins.y2milestone("InstallInf::netdevice:%1", @netdevice)
      if Mode.autoinst
        # if possible, for temporary installation network use same device
        # with same MAC address (even if devicename changed) (bnc#648270)
        new_devname = LanUdevAuto.GetDevnameByMAC(
          Ops.get_string(@InstallInf, "hwaddr", "")
        )
        Builtins.y2milestone("LanUdevAuto::netdevice:%1", new_devname)
        if Ops.greater_than(Builtins.size(new_devname), 0)
          Builtins.y2milestone(
            "old devname: %1, new devname: %2",
            @netdevice,
            new_devname
          )
          @netdevice = new_devname
        end
      end
      if @netdevice != ""
        devtype = NetworkInterfaces.device_type(@netdevice)
        Ops.set(@InstallInf, "type", devtype) if devtype != nil && devtype != "" 
        #	InstallInf = remove(InstallInf, "netdevice");
      end

      if Arch.s390
        Builtins.y2milestone(
          "Interface type: %1",
          Ops.get_string(@InstallInf, "type", "")
        )
        # only some card types need a persistent MAC (bnc#658708)
        sysfs_id = dev_name_to_sysfs_id(@netdevice, @hardware)
        if !s390_device_needs_persistent_mac(sysfs_id, @hardware)
          @InstallInf = Builtins.remove(@InstallInf, "hwaddr")
        end
        # hsi devices do not support setting hwaddr (bnc #479481)
        if Ops.get_string(@InstallInf, "type", "") == "hsi" &&
            Builtins.haskey(@InstallInf, "hwaddr")
          @InstallInf = Builtins.remove(@InstallInf, "hwaddr")
        end
        # set HW address only for qeth set to Layer 2 (bnc #479481)
        if Ops.get_string(@InstallInf, "type", "") == "eth" &&
            Ops.get_string(@InstallInf, "QETH_LAYER2_SUPPORT", "0") != "1"
          @InstallInf = Builtins.remove(@InstallInf, "hwaddr")
        end
      end

      # Split FQ hostname
      hostname = Ops.get_string(@InstallInf, "hostname", "")
      if hostname != "" && !IP.Check(hostname)
        split = Hostname.SplitFQ(hostname)

        # hostname is supposed to be FQDN (http://en.opensuse.org/Linuxrc)
        # so we should not cut off domain name ... anyway remember domain,
        # use it as fallback below, if there is no DNS search domain (#476208)
        if Ops.greater_than(Builtins.size(split), 1)
          Ops.set(@InstallInf, "fqdomain", Ops.get_string(split, 1, ""))
        end
      else
        # do not have numeric hostname, #152218
        Ops.set(@InstallInf, "hostname", "")
      end

      # #180821, todo cleanup
      if @netdevice != ""
        mod = Convert.to_string(
          SCR.Read(Builtins.add(path(".etc.install_inf_alias"), @netdevice))
        )
        if mod != "" && mod != nil
          Ops.set(@InstallInf, "module", mod)
          options = Convert.to_string(
            SCR.Read(Builtins.add(path(".etc.install_inf_options"), mod))
          )
          if options != "" && options != nil
            Ops.set(@InstallInf, "options", options)
          end
        end
      else
        # FIXME: alias = eth0 tulip
        # FIXME: options = ne io=0x200

        # #42203: correctly parse module and options for proposal
        # "eth0 qeth" -> "qeth"
        # FIXME: this only works for a single module
        mod = Ops.get_string(@InstallInf, "module", "")
        Ops.set(@InstallInf, "module", DeleteFirstWord(mod)) if mod != ""

        options = Ops.get_string(@InstallInf, "options", "")
        if options != ""
          Ops.set(@InstallInf, "options", DeleteFirstWord(options))
        end
      end

      Builtins.y2milestone("InstallInf(%1)", @InstallInf)
      true
    end


    # Read module options from /etc/install.inf
    # @param [String] module_name Module name
    # @return module options, empty string if none
    def InstallModuleOptions(module_name)
      if Ops.greater_than(SCR.Read(path(".target.size"), "/etc/install.inf"), 0)
        modules = SCR.Dir(path(".etc.install_inf_options"))
        Builtins.y2milestone(
          "Module with options in /etc/install.inf: %1",
          modules
        )
        if Builtins.contains(modules, module_name)
          options = SCR.Read(
            Builtins.add(path(".etc.install_inf_options"), module_name)
          )
          return Convert.to_string(options) if options != nil && options != ""
        end
      end
      ""
    end

    def StdoutOf(command)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      Ops.get_string(out, "stdout", "")
    end

    def CreateIfcfg
      ifcfg = ""

      if @network_disk == :iscsi &&
          Builtins.contains(
            NetworkStorage.getiBFTDevices,
            Ops.get_string(@InstallInf, "netdevice", "")
          )
        ifcfg = Builtins.sformat(
          "%1STARTMODE='nfsroot'\nBOOTPROTO='ibft'\n",
          ifcfg
        )
      else
        # set BOOTPROTO=[ static | dhcp ]
        if Ops.get_string(@InstallInf, "bootproto", "dhcp") == "static"
          # add broadcast interface #suse49131
          ifcfg = Builtins.sformat(
            "BOOTPROTO='static'\n" +
              "IPADDR='%1/%2'\n" +
              "BROADCAST='%3'\n",
            Ops.get_string(@InstallInf, "ipaddr", ""),
            Netmask.ToBits(Ops.get_string(@InstallInf, "netmask", "")),
            Ops.get_string(@InstallInf, "bcast", "")
          )
          if Ops.greater_than(
              Builtins.size(Ops.get_string(@InstallInf, "ipaddr6", "")),
              0
            )
            ifcfg = Builtins.sformat(
              "%1\n%2",
              ifcfg,
              Builtins.sformat(
                "LABEL_ipv6='ipv6'\nIPADDR_ipv6='%1'\n",
                Ops.get_string(@InstallInf, "ipaddr6", "")
              )
            )
          end
        else
          #DHCP (also for IPv6) setup
          if Ops.get_string(@InstallInf, "bootproto", "") == "dhcp"
            ifcfg = "BOOTPROTO='dhcp4'\n"
          elsif Ops.get_string(@InstallInf, "bootproto", "") == "dhcp6"
            ifcfg = "BOOTPROTO='dhcp6'\n"
          elsif Ops.get_string(@InstallInf, "bootproto", "") == "dhcp,dhcp6"
            ifcfg = "BOOTPROTO='dhcp'\n"
          end

          # set DHCP_SET_HOSTNAME=yes  #suse30528
          Builtins.y2milestone(
            "set DHCLIENT_SET_HOSTNAME=yes on installed system"
          )
          SCR.Execute(
            path(".target.bash_output"),
            "sed -i s/\"DHCLIENT_SET_HOSTNAME=.*\"/'DHCLIENT_SET_HOSTNAME=\"yes\"'/g /etc/sysconfig/network/dhcp"
          )
        end

        if @network_disk == :no
          ifcfg = Builtins.sformat("%1STARTMODE='onboot'\n", ifcfg)
        else
          ifcfg = Builtins.sformat("%1STARTMODE='nfsroot'\n", ifcfg)
        end
      end

      # wireless devices (bnc#223570)
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "WESSID", "")),
          0
        )
        ifcfg = Builtins.sformat(
          "%1WIRELESS_ESSID='%2'\n",
          ifcfg,
          Ops.get_string(@InstallInf, "WESSID", "")
        )

        case Ops.get_string(@InstallInf, "WAuth", "")
          when "", "psk"
            ifcfg = Builtins.sformat(
              "%1WIRELESS_WPA_PSK='%2'\n",
              ifcfg,
              Ops.get_string(@InstallInf, "WKey", "")
            )
            ifcfg = Builtins.sformat("%1WIRELESS_AUTH_MODE='psk'\n", ifcfg)
          when "open"
            ifcfg = Builtins.sformat(
              "%1WIRELESS_AUTH_MODE='no-encryption'\n",
              ifcfg
            )
          when "wep_open", "wep_restricted"
            @type = ""
            if Ops.get_string(@InstallInf, "WkeyType", "") == "password"
              @type = "h:"
            elsif Ops.get_string(@InstallInf, "WkeyType", "") == "ascii"
              @type = "s:"
            end
            ifcfg = Builtins.sformat(
              "%1WIRELESS_AUTH_MODE='%2'\n",
              ifcfg,
              Ops.get_string(@InstallInf, "WAuth", "") == "wep-open" ? "open" : "sharedkey"
            )
            ifcfg = Builtins.sformat("%1WIRELESS_DEFAULT_KEY='0'\n", ifcfg)
            ifcfg = Builtins.sformat(
              "%1WIRELESS_KEY_0='%2%3'\n",
              ifcfg,
              @type,
              Ops.get_string(@InstallInf, "WKey", "")
            )
            ifcfg = Builtins.sformat(
              "%1WIRELESS_KEY_LENGTH='%2'\n",
              ifcfg,
              Ops.get_string(@InstallInf, "WKeyLen", "")
            )
            if Ops.greater_than(
                Builtins.size(Ops.get_string(@InstallInf, "WKeyType", "")),
                0
              ) &&
                Ops.greater_than(
                  Builtins.size(Ops.get_string(@InstallInf, "WKey", "")),
                  0
                )
              ifcfg = Builtins.sformat(
                "%1WIRELESS_KEY_0='%2:%3'\n",
                ifcfg,
                Builtins.substring(
                  Ops.get_string(@InstallInf, "WKeyType", ""),
                  0,
                  1
                ),
                Ops.get_string(@InstallInf, "WKey", "")
              )
            end
        end
      end

      # if available, write MTU
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "mtu", "")),
          0
        )
        ifcfg = Builtins.sformat(
          "%1MTU='%2'\n",
          ifcfg,
          Ops.get_string(@InstallInf, "mtu", "")
        )
      end

      # for queth devices (s390)
      # bnc#578689 - YaST2 should not write the MAC address into ifcfg file
      if Arch.s390 &&
          Ops.greater_than(
            Builtins.size(Ops.get_string(@InstallInf, "hwaddr", "")),
            0
          )
        ifcfg = Builtins.sformat(
          "%1LLADDR='%2'\n",
          ifcfg,
          Ops.get_string(@InstallInf, "hwaddr", "")
        )
      end

      # point to point interface
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "remote_ip", "")),
          0
        )
        ifcfg = Builtins.sformat(
          "%1REMOTE_IPADDR='%2'\n",
          ifcfg,
          Ops.get_string(@InstallInf, "remote_ip", "")
        )
      end

      new_netdevice = @netdevice
      if !LanUdevAuto.AllowUdevModify
        # bnc#821427: use same options as in /lib/udev/rules.d/71-biosdevname.rules
        cmd = Builtins.sformat(
          "biosdevname --policy physical --smbios 2.6 --nopirq -i %1",
          @netdevice
        )
        out = String.FirstChunk(StdoutOf(cmd), "\n")
        if out != ""
          Builtins.y2milestone("biosdevname renames %1 to %2", @netdevice, out)
          new_netdevice = out
        end
      end

      ifcfg_name = Builtins.sformat("ifcfg-%1", new_netdevice)

      hw_name = BuildDescription(
        NetworkInterfaces.device_type(@netdevice),
        NetworkInterfaces.device_num(ifcfg_name),
        { "dev_name" => @netdevice },
        @hardware
      )
      # protect special characters, #305343
      if Ops.greater_than(Builtins.size(hw_name), 0)
        ifcfg = Builtins.sformat("%1NAME='%2'\n", ifcfg, String.Quote(hw_name))
      end

      Builtins.y2milestone(
        "Network Configuration:\n%1\nifcfg file: %2",
        ifcfg,
        ifcfg_name
      )

      # write only if file doesn't exists
      dev_file = Builtins.sformat("/etc/sysconfig/network/%1", ifcfg_name)

      SCR.Write(path(".target.string"), dev_file, ifcfg)
      Builtins.y2milestone("ifcfg file: %1", dev_file)

      nil
    end

    # create all network files except ifcfg and hwcfg
    # directly to installed system

    def CreateOtherNetworkFiles
      # create hostname
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "hostname", "")),
          0
        )
        Builtins.y2milestone(
          "Write HOSTNAME: %1",
          Ops.get_string(@InstallInf, "hostname", "")
        )
        SCR.Write(
          path(".target.string"),
          "/etc/HOSTNAME",
          Ops.get_string(@InstallInf, "hostname", "")
        )
      end

      if Ops.get_string(@InstallInf, "bootproto", "dhcp") == "static"
        # create routes file
        if Ops.greater_than(
            Builtins.size(Ops.get_string(@InstallInf, "gateway", "")),
            0
          )
          Builtins.y2milestone(
            "Writing route : %1",
            Ops.get_string(@InstallInf, "gateway", "")
          )
          SCR.Write(
            path(".target.string"),
            "/etc/sysconfig/network/routes",
            Builtins.sformat(
              "default %1 - -\n",
              Ops.get_string(@InstallInf, "gateway", "")
            )
          )
        elsif Ops.greater_than(
            Builtins.size(Ops.get_string(@InstallInf, "remote_ip", "")),
            0
          )
          Builtins.y2milestone(
            "Writing Peer-to-Peer route: %1",
            Ops.get_string(@InstallInf, "remote_ip", "")
          )
          SCR.Write(
            path(".target.string"),
            "/etc/sysconfig/network/routes",
            Builtins.sformat(
              "default %1 - -\n",
              Ops.get_string(@InstallInf, "remote_ip", "")
            )
          )
        else
          Builtins.y2warning("No routing information in install.inf")
        end

        # write DHCPTimeout linuxrc parameter as /etc/sysconfig/network/config.WAIT_FOR_INTERFACES (bnc#396824)
        if Ops.greater_than(
            Builtins.size(Ops.get_string(@InstallInf, "dhcptimeout", "")),
            0
          )
          SCR.Write(
            path(".sysconfig.network.config.WAIT_FOR_INTERFACES"),
            Ops.get_string(@InstallInf, "dhcptimeout", "")
          )
          Builtins.y2milestone(
            "Writing WAIT_FOR_INTERFACES=%1",
            Ops.get_string(@InstallInf, "dhcptimeout", "")
          )
        end


        # create resolv.conf only for static configuration
        if Ops.greater_than(
            Builtins.size(Ops.get_string(@InstallInf, "nameserver", "")),
            0
          )
          serverlist = Ops.get_string(@InstallInf, "nameserver", "")
          # write also secondary and third nameserver when available (bnc#446101)
          if Ops.greater_than(
              Builtins.size(Ops.get_string(@InstallInf, "nameserver2", "")),
              0
            )
            serverlist = Builtins.sformat(
              "%1 %2",
              serverlist,
              Ops.get_string(@InstallInf, "nameserver2", "")
            )
          end
          if Ops.greater_than(
              Builtins.size(Ops.get_string(@InstallInf, "nameserver3", "")),
              0
            )
            serverlist = Builtins.sformat(
              "%1 %2",
              serverlist,
              Ops.get_string(@InstallInf, "nameserver3", "")
            )
          end
          #Do not write /etc/resolv.conf directly, feed the data to sysconfig instead,
          #'netconfig' will do the job later on network startup (FaTE #303618)
          SCR.Write(
            path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS"),
            serverlist
          )
          Builtins.y2milestone(
            "Writing static nameserver entry: %1",
            Ops.get_string(@InstallInf, "nameserver", "")
          )

          #Enter search domain data only if present
          if Ops.greater_than(
              Builtins.size(Ops.get_string(@InstallInf, "domain", "")),
              0
            )
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
              Ops.get_string(@InstallInf, "domain", "")
            )
            Builtins.y2milestone(
              "Writing static searchlist entry: %1",
              Ops.get_string(@InstallInf, "domain", "")
            )
          elsif Ops.greater_than(
              Builtins.size(Ops.get_string(@InstallInf, "fqdomain", "")),
              0
            )
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
              Ops.get_string(@InstallInf, "fqdomain", "")
            )
            Builtins.y2milestone(
              "No DNS search domain defined, using FQ domain name %1 as a fallback",
              Ops.get_string(@InstallInf, "fqdomain", "")
            )
          end

          #We're done. It is OK not to touch NETCONFIG_DNS_POLICY now as it is set to 'auto' by default
          #and user did not have a chance to modify it up to now
          SCR.Write(path(".sysconfig.network.config"), nil)
        end
      end

      # create proxy sysconfig file
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "proxyProto", "")),
          0
        ) &&
          Ops.greater_than(
            Builtins.size(Ops.get_string(@InstallInf, "proxyUrl", "")),
            0
          )
        Builtins.y2milestone(
          "Writing proxy settings: %1",
          Ops.get_string(@InstallInf, "proxyUrl", "")
        )

        Proxy.Read
        ex = Proxy.Export

        # bnc#693640 - update Proxy module's configuration
        # username and password is stored in url because it is handled by linuxrc this way and it is impossible
        # to distinguish how the user inserted it (separate or as a part of url?)
        Ops.set(
          ex,
          Ops.add(Ops.get_string(@InstallInf, "proxyProto", ""), "_proxy"),
          Ops.get_string(@InstallInf, "proxyUrl", "")
        )

        Proxy.Import(ex)
        Proxy.Write

        Builtins.y2debug("Written proxy settings: %1", ex)
      end
      # create defaultdomain
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "nisdomain", "")),
          0
        ) &&
          FileUtils.Exists("/etc/defaultdomain")
        Builtins.y2milestone(
          "Write defaultdomain: %1",
          Ops.get_string(@InstallInf, "nisdomain", "")
        )
        SCR.Write(
          path(".target.string"),
          "/etc/defaultdomain",
          Ops.get_string(@InstallInf, "nisdomain", "")
        )
      end

      # write wait_for_interfaces if needed
      if Ops.greater_than(
          Builtins.size(Ops.get_string(@InstallInf, "connect_wait", "")),
          0
        )
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "sed -i s/^WAIT_FOR_INTERFACES=.*/WAIT_FOR_INTERFACES=%1/g /etc/sysconfig/network/config",
            Ops.get_string(@InstallInf, "connect_wait", "")
          )
        )
      end

      nil
    end

    def CopyConfiguredNetworkFiles
      Builtins.y2milestone(
        "Copy network configuration files from 1st stage into installed system"
      )
      sysconfig = "/etc/sysconfig/network/"
      copy_to = String.Quote(
        Builtins.sformat("%1%2", Installation.destdir, sysconfig)
      )

      # just copy files
      Builtins.foreach(["ifcfg-*", "routes"]) do |file|
        copy_from = String.Quote(Builtins.sformat("%1%2", sysconfig, file))
        Builtins.y2milestone("Copy %1 into %2", copy_from, copy_to)
        cmd = Builtins.sformat("cp %1 %2", copy_from, copy_to)
        ret = SCR.Execute(path(".target.bash_output"), cmd)

        Builtins.y2error("cmd: '#{cmd}' failed: #{ret}") if ret["exit"] != 0
      end

      # merge files with default installed by sysconfig
      Builtins.foreach(["dhcp", "config"]) do |file|
        source_file = Builtins.sformat("%1%2", sysconfig, file)
        dest_file = Builtins.sformat("%1%2", copy_to, file)
        # apply options from initrd configuration files into installed system
        # i.e. just modify (not replace) files from sysconfig rpm
        # FIXME this must be ripped out, refactored and tested
        # In particular, values containing slashes will break the last sed
        cmd2 = "\n" +
          "grep -v \"^[[:space:]]*#\" $source_file | grep = | while read option\n" +
          " do\n" +
          "  key=${option%=*}=\n" +
          "  grep -v \"^[[:space:]]*#\" $dest_file | grep -q $key\n" +
          "  if [ $? != \"0\" ]\n" +
          "   then\n" +
          "    echo \"$option\" >> $dest_file\n" +
          "   else\n" +
          "    sed -i s/\"^[[:space:]]*$key.*\"/\"$option\"/g $dest_file\n" +
          "  fi\n" +
          " done"
        cmd1 = Builtins.sformat(
          "source_file=%1;dest_file=%2\n",
          source_file,
          dest_file
        )
        # merge commands (add file-path variables) because of some sformat limits with % character
        command = Builtins.sformat("%1%2", cmd1, cmd2)
        Builtins.y2milestone(
          "Execute file merging script : %1",
          SCR.Execute(path(".target.bash_output"), command)
        )
      end 
      #FIXME: proxy

      nil
    end



    # this replaces bash script create_interface
    def save_network
      Builtins.y2milestone("starting save_network")
      # skip from chroot
      old_SCR = WFM.SCRGetDefault
      new_SCR = WFM.SCROpen("chroot=/:scr", false)
      WFM.SCRSetDefault(new_SCR)

      # when root is on nfs/iscsi set startmode=nfsroot #176804
      device = NetworkStorage.getDevice(Installation.destdir)
      Builtins.y2debug(
        "%1 directory is on %2 device",
        Installation.destdir,
        device
      )
      @network_disk = NetworkStorage.isDiskOnNetwork(device)
      Builtins.y2milestone("Network based device: %1", @network_disk)


      if Arch.s390
        Builtins.y2milestone(
          "For s390 architecture copy udev rule files (/etc/udev/rules/51*)"
        )
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p %1/51-* '%2%1'",
            "/etc/udev/rules.d",
            String.Quote(Installation.destdir)
          )
        )
      end
      # --------------------------------------------------------------
      # Copy DHCP client cache so that we can request the same IP (#43974).
      WFM.Execute(
        path(".local.bash"),
        Builtins.sformat(
          "mkdir -p '%2%1'; /bin/cp -p %1/dhcpcd-*.cache '%2%1'",
          "/var/lib/dhcpcd",
          String.Quote(Installation.destdir)
        )
      )
      # Copy DHCPv6 (DHCP for IPv6) client cache.
      WFM.Execute(
        path(".local.bash"),
        Builtins.sformat(
          "/bin/cp -p %1/ '%2%1'",
          "/var/lib/dhcpv6",
          String.Quote(Installation.destdir)
        )
      )

      #Deleting lockfiles and re-triggering udev events for *net is not needed any more
      #(#292375 c#18)

      udev_rules_srcdir = "/etc/udev/rules.d"
      net_srcfile = "70-persistent-net.rules"

      udev_rules_destdir = Builtins.sformat(
        "%1%2",
        String.Quote(Installation.destdir),
        udev_rules_srcdir
      )
      net_destfile = Builtins.sformat(
        "%1%2/%3",
        String.Quote(Installation.destdir),
        udev_rules_srcdir,
        net_srcfile
      )

      Builtins.y2milestone("udev_rules_destdir %1", udev_rules_destdir)
      Builtins.y2milestone("net_destfile %1", net_destfile)

      #Do not create udev_rules_destdir if it already exists (in case of update)
      #(bug #293366, c#7)

      if !FileUtils.Exists(udev_rules_destdir)
        Builtins.y2milestone(
          "%1 does not exist yet, creating it",
          udev_rules_destdir
        )
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat("mkdir -p '%1'", udev_rules_destdir)
        )
      else
        Builtins.y2milestone("File %1 exists", udev_rules_destdir)
      end

      if !FileUtils.Exists(net_destfile)
        Builtins.y2milestone("Copying %1 to the installed system ", net_srcfile)
        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p '%1/%2' '%3'",
            udev_rules_srcdir,
            net_srcfile,
            net_destfile
          )
        )
      else
        Builtins.y2milestone("Not copying file %1 - it already exists", net_destfile)
      end

      if ReadInstallInf()
        CopyConfiguredNetworkFiles()
      else
        Builtins.y2error("Error while reading install.inf!")
      end

      # close and chroot back
      WFM.SCRSetDefault(old_SCR)
      WFM.SCRClose(new_SCR)

      LanUdevAuto.Write if Mode.autoinst

      SCR.Execute(path(".target.bash"), "chkconfig network on")

      # if portmap running - start it after reboot
      WFM.Execute(
        path(".local.bash"),
        "pidofproc rpcbind && touch /var/lib/YaST2/network_install_rpcbind"
      )

      nil
    end
  end
end

Yast::SaveNetworkClient.new.main
