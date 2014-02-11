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
# File:	include/network/complex.ycp
# Package:	Network configuration
# Summary:	Summary and overview functions
# Authors:	Michal Svec <msvec@suse.cz>
#
#
module Yast
  module NetworkComplexInclude
    def initialize_network_complex(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "NetHwDetection"
      Yast.import "HTML"
      Yast.import "NetworkInterfaces"
      Yast.import "Popup"
      Yast.import "String"
      Yast.import "Summary"
      Yast.import "NetworkService"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/summary.rb"
    end

    # Used for initializing the description variable (ifcfg[NAME])
    # The code is mostly moved from BuildSummaryDevs
    # Take the NAME field from ifcfg
    # If empty, identify the hardware and use its data
    def BuildDescription(devtype, devnum, devmap, _Hardware)
      descr = devmap["NAME"] || ""
      return descr if descr != ""
      descr = HardwareName(_Hardware, devnum)
      return descr if descr != ""
      descr = HardwareName(_Hardware, devmap["UNIQUE"] || "")
      return descr if descr != ""

      CheckEmptyName(devtype, descr)
    end

    # TODO move to HTML.ycp
    def Hyperlink(href, text)
      Builtins.sformat("<a href=\"%1\">%2</a>", href, text)
    end

    # Build textual summary
    # @param [Boolean] split split configured and unconfigured?
    # @param [Boolean] link  add a link to configure the device (only if !split)
    # @return [ configured, unconfigured ] if split, [ summary, links ] otherwise
    def BuildSummaryDevs(_Devs, _Hardware, split, link)
      _Devs = deep_copy(_Devs)
      _Hardware = deep_copy(_Hardware)
      Builtins.y2milestone("Devs=%1", NetworkInterfaces.ConcealSecrets(_Devs))
      Builtins.y2milestone("Hardware=%1", _Hardware)
      Builtins.y2debug("split=%1", split)

      uniques = []
      uniques_old = []
      configured = []
      unconfigured = []
      links = []

      # build a list of configured devices
      Builtins.maplist(_Devs) do |devtype, devsmap|
        Builtins.maplist(
          Convert.convert(devsmap, :from => "map", :to => "map <string, map>")
        ) do |devname, devmap|
          # main device summary
          descr = BuildDescription(devtype, devname, devmap, _Hardware)
          unq = Ops.get_string(devmap, "UNIQUE", "")
          status = DeviceStatus(devtype, devname, devmap)
          if link
            if devtype == "wlan" &&
                Ops.get_string(devmap, "WIRELESS_AUTH_MODE", "") == "open" &&
                Ops.get_string(devmap, "WIRELESS_KEY_0", "") == ""
              href = Ops.add("lan--wifi-encryption-", devname)
              # interface summary: WiFi without encryption
              warning = HTML.Colorize(
                _("Warning: no encryption is used."),
                "red"
              )
              status = Ops.add(
                Ops.add(Ops.add(Ops.add(status, " "), warning), " "),
                # Hyperlink: Change the configuration of an interface
                Hyperlink(href, _("Change."))
              )
              links = Builtins.add(links, href)
            end
          end
          configured = Builtins.add(configured, Summary.Device(descr, status))
          uniques = Builtins.add(uniques, devname)
          uniques_old = Builtins.add(uniques_old, unq)
          # aliases summary
          aliasee = Ops.get_map(devmap, "_aliases", {})
          Builtins.maplist(aliasee) do |aid, amap|
            # Table item
            # this is what used to be Virtual Interface
            # (eth0:1)
            descr = _("Additional Address")
            status = DeviceStatus(devtype, devname, amap)
            configured = Builtins.add(configured, Summary.Device(descr, status))
          end if aliasee != {}
        end
      end

      Builtins.y2debug("uniques(%1)", uniques)
      Builtins.y2debug("uniques_old(%1)", uniques_old)

      # build a list of unconfigured devices
      id = 0
      Builtins.maplist(_Hardware) do |h|
        unq = Ops.get_string(h, "unique", "")
        busid = Ops.add(
          Ops.add(Ops.add("bus-", Ops.get_string(h, "bus", "")), "-"),
          Ops.get_string(h, "busid", "")
        )
        mac = Ops.add("id-", Ops.get_string(h, "mac", ""))
        hwtype = Ops.get_string(h, "type", "")
        hwname = CheckEmptyName(hwtype, Ops.get_string(h, "name", ""))
        Builtins.y2debug("busid=%1, mac=%2", busid, mac)
        if !Builtins.contains(uniques, busid) &&
            !Builtins.contains(uniques, mac) &&
            !Builtins.contains(uniques_old, unq)
          if split && !Builtins.contains(uniques_old, unq)
            Ops.set(h, "id", id)
            unconfigured = Builtins.add(unconfigured, h)
          else
            configured = Builtins.add(
              configured,
              Summary.Device(hwname, Summary.NotConfigured)
            )
          end
        end
        id = Ops.add(id, 1)
      end

      Builtins.y2debug("configured=%1", configured)
      Builtins.y2debug("unconfigured=%1", unconfigured)

      # create a summary text
      summary = Summary.DevicesList(configured)
      # if not split -> summary is finished
      return [summary, links] if !split

      # add headers
      if Ops.greater_than(Builtins.size(configured), 0)
        # Summary text
        summary = Ops.add(
          Summary.AddHeader("", _("Already Configured Devices:")),
          summary
        )
      else
        # Summary text
        summary = Summary.AddHeader("", _("Nothing is configured"))
      end

      # create a table of unconfigured devices
      selected = Ops.get_integer(unconfigured, [0, "num"], -1)
      #    list devs = hwlist2items(unconfigured, selected);

      # FIXME OtherDevices(devs, type);

      # Label for not detected devices
      #    devs = add(devs, `item(`id(`other), _("Other (not detected)"), size(devs) == 0));

      Builtins.y2debug("summary=%1", summary)
      #    y2debug("devs=%1", devs);

      [summary, unconfigured] 
      #    return [ summary, devs ];
    end

    # Build textual summary
    # @param [Boolean] split split configured and unconfigured?
    # @param [Boolean] link  add a link to configure the device (only if !split)
    # @return [ configured, unconfigured ] if split, [ summary, links ] otherwise
    def BuildSummary(devregex, _Hardware, split, link)
      _Hardware = deep_copy(_Hardware)
      _Devs = NetworkInterfaces.FilterDevices(devregex)
      ret = BuildSummaryDevs(_Devs, _Hardware, split, link)
      deep_copy(ret)
    end
    def CheckEmptyName(devtype, hwname)
      return hwname if hwname != nil && hwname != ""

      device_names = {
        # Device type label
        "contr-pcmcia" => _("PCMCIA ISDN Card"),
        # Device type label
        "contr-usb"    => _("USB ISDN Card"),
        # Device type label
        "eth-pcmcia"   => _("PCMCIA Ethernet Network Card"),
        # Device type label
        "eth-usb"      => _("USB Ethernet Network Card"),
        # Device type label
        "fddi-pcmcia"  => _("PCMCIA FDDI Network Card"),
        # Device type label
        "fddi-usb"     => _("USB FDDI Network Card"),
        # Device type label
        "ippp-pcmcia"  => _("PCMCIA ISDN Connection"),
        # Device type label
        "ippp-usb"     => _("USB ISDN Connection"),
        # Device type label
        "isdn-pcmcia"  => _("PCMCIA ISDN Connection"),
        # Device type label
        "isdn-usb"     => _("USB ISDN Connection"),
        # Device type label
        "modem-pcmcia" => _("PCMCIA Modem"),
        # Device type label
        "modem-usb"    => _("USB Modem"),
        # Device type label
        "ppp-pcmcia"   => _("PCMCIA Modem"),
        # Device type label
        "ppp-usb"      => _("USB Modem"),
        # Device type label
        "tr-pcmcia"    => _(
          "PCMCIA Token Ring Network Card"
        ),
        # Device type label
        "tr-usb"       => _("USB Token Ring Network Card"),
        # Device type label
        "usb-usb"      => _("USB Network Device"),
        # Device type label
        "wlan-pcmcia"  => _("PCMCIA Wireless Network Card"),
        # Device type label
        "wlan-usb"     => _("USB Wireless Network Card")
      }

      if Builtins.haskey(device_names, devtype)
        return Ops.get_string(device_names, devtype, "")
      else
        descr = NetworkInterfaces.GetDevTypeDescription(devtype, true)
        return descr if IsNotEmpty(descr)
      end

      if Builtins.haskey(device_names, Ops.add(devtype, "-"))
        Builtins.y2warning("- device found: %1, %2", devtype, hwname)
        return Ops.get_string(device_names, Ops.add(devtype, "-"), "")
      end

      Builtins.y2error("Unknown type: %1", devtype)
      # Device type label
      _("Unknown Network Device")
    end

    def HardwareName(_Hardware, id)
      return "" if id.nil? || id.empty?
      return "" if _Hardware.nil? || _Hardware.empty?

      # filter out a list of hwinfos which correspond to the given id
      res_list = _Hardware.select do |h|
        have = [
          "id-" + (h["mac"] || ""),
          "bus-" + (h["bus"] || "") + "-" + (h["busid"] || ""),
          h["udi"] || "",
          h["dev_name"] || ""
        ]

        have.include?(id)
      end

      # take first item from the list - there should be just one
      if res_list.empty?
        Builtins.y2warning("HardwareName: no matching hardware for id=#{id}")

        return ""
      else
        hwname = res_list.first["name"] || ""
        Builtins.y2milestone("HardwareName: hwname=#{hwname} for id=#{id}")

        return hwname
      end
    end

    # Get aprovider name from the provider map
    # @param [String] provider identifier
    # @return provider name
    # @example ProviderName("tonline") -> "T-Online"
    def ProviderName(provider)
      Yast.import "Provider"

      return "" if provider == nil || provider == ""

      Provider.Select(provider)
      nam = Ops.get_string(Provider.Current, "PROVIDER", provider)
      return provider if nam == nil || nam == ""
      nam
    end
    def DeviceStatus(devtype, devname, devmap)
      devmap = deep_copy(devmap)
      # Modem and DSL
      if devtype == "ppp" || devtype == "modem" || devtype == "dsl"
        nam = ProviderName(Ops.get_string(devmap, "PROVIDER", ""))

        if nam == "" || nam == nil
          # Modem status (%1 is device)
          return Builtins.sformat(_("Configured as %1"), devname)
        else
          # Modem status (%1 is device, %2 is provider)
          return Builtins.sformat(
            _("Configured as %1 with provider %2"),
            devname,
            nam
          )
        end
      # ISDN card
      elsif devtype == "isdn" || devtype == "contr"
        # ISDN device status (%1 is device)
        return Builtins.sformat(_("Configured as %1"), devname)
      # ISDN stuff
      elsif devtype == "net"
        nam = ProviderName(Ops.get_string(devmap, "PROVIDER", ""))
        # Connection protocol (syncppp|rawip)
        proto = Ops.get_string(devmap, "PROTOCOL", "")

        # ISDN status (%1 is device, %2 is provider, %3 protocol)
        return Builtins.sformat(
          _("Configured as %1 with provider %2 (protocol %3)"),
          devname,
          nam,
          proto
        ) 

        # example: ISDN Connection to Arcor with syncppp on net0
        # return sformat(_("to %1 with %2 on %3"), provider, proto, dev);
      else
        # if(!regexpmatch(devtype, NetworkAllRegex))
        #     y2error("Unknown type: %1", devtype);

        proto = Ops.get_string(devmap, "BOOTPROTO", "static")

        if proto == "" || proto == "static" || proto == "none" || proto == nil
          addr = Ops.get_string(devmap, "IPADDR", "")
          host = NetHwDetection.ResolveIP(addr)
          remip = Ops.get_string(devmap, "REMOTE_IPADDR", "")
          if proto == "none"
            return _("Configured without address (NONE)")
          elsif IsEmpty(addr)
            # Network card status
            return HTML.Colorize(_("Configured without an address"), "red")
          elsif remip == "" || remip == nil
            # Network card status (%1 is address)
            return Builtins.sformat(
              _("Configured with address %1"),
              Ops.add(addr, String.OptParens(host))
            )
          else
            # Network card status (%1 is address, %2 is address)
            return Builtins.sformat(
              _("Configured with address %1 (remote %2)"),
              addr,
              remip
            )
          end
        else
          # Network card status (%1 is protocol)
          return Builtins.sformat(
            _("Configured with %1"),
            Builtins.toupper(proto)
          )
        end

        # This is the old version of the above code, including the
        # configuration name. But the name is long and cryptic so wen
        # don't use it.
        # FIXME: dropped interface name
        if proto == "" || proto == "static" || proto == "none" || proto == nil
          addr = Ops.get_string(devmap, "IPADDR", "")
          remip = Ops.get_string(devmap, "REMOTE_IPADDR", "")
          if addr == "" || addr == nil
            # Network card status (%1 is device)
            return Builtins.sformat(_("Configured as %1"), devname)
          elsif remip == "" || remip == nil
            # Network card status (%1 is device, %2 is address)
            return Builtins.sformat(
              _("Configured as %1 with address %2"),
              devname,
              addr
            )
          else
            # Network card status (%1 is device, %2 is address, %3 is address)
            return Builtins.sformat(
              _("Configured as %1 with address %2 (remote %3)"),
              devname,
              addr,
              remip
            )
          end
        else
          # Network card status (%1 is device, %2 is protocol)
          return Builtins.sformat(
            _("Configured as %1 with %2"),
            devname,
            Builtins.toupper(proto)
          )
        end
      end
    end

    # Return the device protocol or IP address in case of static config
    # Or indicate that NetworkManager takes over.
    # @param [Hash] devmap device map
    # @return textual device protocol
    def DeviceProtocol(devmap)
      devmap = deep_copy(devmap)
      if Ops.get_string(devmap, "STARTMODE", "") == "managed"
        # Abbreviation for "The interface is Managed by NetworkManager"
        return _("Managed")
      end
      ip = Ops.get_string(devmap, "BOOTPROTO", "static")
      if ip == nil || ip == "" || ip == "static"
        ip = Ops.get_string(devmap, "IPADDR", "")
      else
        ip = Builtins.toupper(ip)
      end
      ip
    end

    # Return description used for device summary dialog
    # In case device is not connected "(not connected)" string
    # will be added.
    # Description also contains MAC address or BusID information.

    def getConnMacBusDescription(v, _Hardware)
      v = deep_copy(v)
      _Hardware = deep_copy(_Hardware)
      descr = ""
      conn = ""
      mac_dev = ""
      Builtins.foreach(_Hardware) do |device|
        if Ops.get_string(v, "UNIQUE", "") ==
            Ops.get_string(device, "unique_key", "")
          conn = HTML.Bold(
            Ops.get_boolean(device, "link", false) == true ?
              "" :
              _("(not connected)")
          )
          if Ops.greater_than(
              Builtins.size(Ops.get_string(device, "mac", "")),
              0
            )
            mac_dev = Ops.add(
              Ops.add(HTML.Bold("MAC : "), Ops.get_string(device, "mac", "")),
              "<br>"
            )
          elsif Ops.greater_than(
              Builtins.size(Ops.get_string(device, "busid", "")),
              0
            )
            mac_dev = Ops.add(
              Ops.add(
                HTML.Bold("BusID : "),
                Ops.get_string(device, "busid", "")
              ),
              "<br>"
            )
          end
        end
      end
      descr = Ops.add(Ops.add(Ops.add(" ", conn), "<br>"), mac_dev)
      descr
    end

    # Create overview table contents
    # List of terms
    # `item (`id (id), ...)
    # @return table items
    def BuildOverviewDevs(_Devs, _Hardware)
      _Devs = deep_copy(_Devs)
      _Hardware = deep_copy(_Hardware)
      overview = []

      startmode_descrs = {
        # summary description of STARTMODE=auto
        "auto"    => _(
          "Started automatically at boot"
        ),
        # summary description of STARTMODE=hotplug
        "hotplug" => _(
          "Started automatically at boot"
        ),
        # summary description of STARTMODE=ifplugd
        "ifplugd" => _(
          "Started automatically on cable connection"
        ),
        # summary description of STARTMODE=managed
        "managed" => _(
          "Managed by NetworkManager"
        ),
        # summary description of STARTMODE=off
        "off"     => _(
          "Will not be started at all"
        )
      }

      Builtins.maplist(_Devs) do |type, devmap|
        Builtins.maplist(
          Convert.convert(devmap, :from => "map", :to => "map <string, map>")
        ) do |devname, v|
          item = nil
          ip = DeviceProtocol(v)
          descr = BuildDescription(type, devname, v, _Hardware)
          startmode_descr = Ops.get_locale(
            startmode_descrs,
            Ops.get_string(v, "STARTMODE", ""),
            _("Started manually")
          )
          # Modem and DSL
          if type == "ppp" || type == "modem" || type == "dsl"
            # create the rich text description
            rich = Ops.add(
              Ops.add(HTML.Bold(descr), "<br>"),
              HTML.List(
                [
                  Builtins.sformat(_("Device Name: %1"), devname),
                  Builtins.sformat(
                    _("Mode: %1"),
                    Ops.get_locale(v, "PPPMODE", _("Unknown"))
                  ),
                  startmode_descr
                ]
              )
            )
            item = Item(
              Id(devname),
              devname,
              NetworkInterfaces.GetDevTypeDescription(type, false),
              ProviderName(Ops.get_string(v, "PROVIDER", "")),
              rich
            )
          # ISDN stuff
          elsif type == "contr"
            # FIXME: richtext
            cname = Ops.get_string(v, "NAME", "unknown")
            item = Item(
              Id(devname), #, "active?", ip, "?", "?"
              devname,
              NetworkInterfaces.GetDevTypeDescription(type, false),
              cname
            )
          # ISDN stuff
          elsif type == "net"
            # FIXME: richtext
            cname = Ops.get_string(v, "PROVIDER", "unknown")
            rip = Ops.get_string(v, "PTPADDR", "none")
            proto = Ops.get_string(v, "PROTOCOL", "unknown")
            item = Item(Id(devname), devname, proto, cname, ip, rip)
          else
            # if(!regexpmatch(type, NetworkAllRegex))
            #     y2error("Unknown type: %1", type);

            bullets = [
              Builtins.sformat(_("Device Name: %1"), devname),
              startmode_descr
            ]
            if Ops.get_string(v, "STARTMODE", "") != "managed"
              if ip != "NONE"
                bullets = Ops.add(
                  bullets,
                  [
                    ip == "DHCP" ?
                      _("IP address assigned using DHCP") :
                      Builtins.sformat(
                        _("IP address: %1, subnet mask %2"),
                        ip,
                        Ops.get_string(v, "NETMASK", "")
                      )
                  ]
                )
              end

              # build aliases overview
              if Ops.greater_than(
                  Builtins.size(Ops.get_map(v, "_aliases", {})),
                  0
                ) &&
                  !NetworkService.is_network_manager
                Builtins.foreach(Ops.get_map(v, "_aliases", {})) do |key, desc|
                  parameters = Builtins.sformat(
                    _("IP address: %1, subnet mask %2"),
                    Ops.get_string(desc, "IPADDR", ""),
                    Ops.get_string(desc, "NETMASK", "")
                  )
                  bullets = Builtins.add(
                    bullets,
                    Builtins.sformat("%1 (%2)", key, parameters)
                  )
                end
              end
            end

            # build the "Bond Slaves" entry of rich box
            if type == "bond"
              slaves = ""
              Builtins.foreach(
                Convert.convert(v, :from => "map", :to => "map <string, any>")
              ) do |key, value|
                if value != nil &&
                    Builtins.regexpmatch(key, "BONDING_SLAVE[0-9]")
                  slaves = Ops.add(
                    Ops.add(slaves, slaves != "" ? ", " : ""),
                    Convert.to_string(value)
                  )
                end
              end
              if slaves != ""
                bullets = Ops.add(
                  bullets,
                  [Ops.add(_("Bond slaves") + " : ", slaves)]
                )
              end
            end

            rich = descr
            rich = Ops.add(
              Ops.add(HTML.Bold(rich), getConnMacBusDescription(v, _Hardware)),
              HTML.List(bullets)
            )
            hw_id = -1
            found = false
            Builtins.foreach(_Hardware) do |device|
              hw_id = Ops.add(hw_id, 1)
              if Ops.get_string(v, "UNIQUE", "") ==
                  Ops.get_string(device, "unique_key", "")
                found = true
                raise Break
              end
            end

            item = Item(Id(devname), descr, ip, rich, found ? hw_id : -1)
          end
          overview = Builtins.add(overview, item)
        end
      end

      Builtins.y2debug("overview=%1", overview)
      deep_copy(overview)
    end

    # Create overview table contents
    # @return table items
    def BuildOverview(devregex, _Hardware)
      _Hardware = deep_copy(_Hardware)
      _Devs = NetworkInterfaces.FilterDevices(devregex)
      BuildOverviewDevs(_Devs, _Hardware)
    end

    # Convert the output of BuildSummary for inclusion in the unified device list.
    # Called by BuildUnconfigured and BuildUnconfiguredDevs.
    # @param [Array] sum output of BuildSumary
    # @param [String] class netcard modem dsl, isdn too;
    # determines how to arrange output, yuck
    # @return [ $[id, table_descr, rich descr] ]
    def BuildUnconfiguredCommon(sum, _class)
      sum = deep_copy(sum)
      # unconfigured devices
      #    list<term> res = sum[1]:[`item(`id(`other))];
      # filter out the item for adding an unknown one
      #    list res = filter (term card, sum, ``( card[0,0]:nil != `other ));
      # translators: this device has not been configured yet
      nc = _("Not configured")
      Builtins.maplist(
        Convert.convert(sum, :from => "list", :to => "list <map <string, any>>")
      ) do |card|
        # configured cards are identified by the string after ifcfg-,
        # unconfigured ones by "-%1" where %1 is the index in hardware list
        id = Builtins.sformat("-%1", Ops.get_integer(card, "id", 0))
        name = Ops.get_string(card, "name", "")
        desc = []
        case _class
          when "netcard"
            desc = [name, nc]
          when "dsl", "modem"
            desc = [
              name,
              NetworkInterfaces.GetDevTypeDescription(_class, false),
              nc
            ]
          when "isdn"
            desc = [
              nc,
              NetworkInterfaces.GetDevTypeDescription(_class, false),
              name
            ]
          else
            Builtins.y2warning(1, "invalid class %1", _class)
        end
        rich = Ops.add(
          Ops.add(
            HTML.Bold(name),
            getConnMacBusDescription(
              card,
              Convert.convert(sum, :from => "list", :to => "list <map>")
            )
          ),
          _(
            "<p>The device is not configured. Press <b>Edit</b> for configuration.</p>"
          )
        )
        { "id" => id, "table_descr" => desc, "rich_descr" => rich }
      end
    end

    # @param [Hash{String => map}] Devs configured devices
    # @param [String] class netcard modem dsl, isdn too
    # @param [Array<Hash>] Hardware the detected hardware
    # @return [ $[id, table_descr, rich descr] ]
    def BuildUnconfiguredDevs(_Devs, _class, _Hardware)
      _Devs = deep_copy(_Devs)
      _Hardware = deep_copy(_Hardware)
      split = true
      proposal = false
      sum = BuildSummaryDevs(_Devs, _Hardware, split, proposal)
      BuildUnconfiguredCommon(
        Ops.get_list(sum, Ops.subtract(Builtins.size(sum), 1), []),
        _class
      )
    end

    # @param [String] class netcard modem dsl. not isdn because it does not use
    # NetworkInterfaces (#103073)
    # @param [Array<Hash>] Hardware the detected hardware
    # @return [ $[id, table_descr, rich descr] ]
    def BuildUnconfigured(_class, _Hardware)
      _Hardware = deep_copy(_Hardware)
      split = true
      proposal = false
      sum = BuildSummary(_class, _Hardware, split, proposal)
      BuildUnconfiguredCommon(
        Ops.get_list(sum, Ops.subtract(Builtins.size(sum), 1), []),
        _class
      )
    end
  end
end
