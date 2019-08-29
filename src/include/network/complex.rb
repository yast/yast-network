# encoding: utf-8

# ***************************************************************************
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
# **************************************************************************
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

      Yast.include include_target, "network/routines.rb"
    end

    # Used for initializing the description variable (ifcfg[NAME])
    # The code is mostly moved from BuildSummaryDevs
    # Take the NAME field from ifcfg
    # If empty, identify the hardware and use its data
    def BuildDescription(devtype, devnum, devmap, hardware)
      descr = devmap["NAME"] || ""
      return descr if descr != ""
      descr = HardwareName(hardware, devnum)
      return descr if descr != ""
      descr = HardwareName(hardware, devmap["UNIQUE"] || "")
      return descr if descr != ""

      CheckEmptyName(devtype, descr)
    end

    # TODO: move to HTML.ycp
    def Hyperlink(href, text)
      Builtins.sformat("<a href=\"%1\">%2</a>", href, text)
    end

    def CheckEmptyName(devtype, hwname)
      return hwname if !hwname.nil? && hwname != ""

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

      return Ops.get_string(device_names, devtype, "") if Builtins.haskey(device_names, devtype)

      descr = NetworkInterfaces.GetDevTypeDescription(devtype, true)
      return descr if IsNotEmpty(descr)

      if Builtins.haskey(device_names, Ops.add(devtype, "-"))
        Builtins.y2warning("- device found: %1, %2", devtype, hwname)
        return Ops.get_string(device_names, Ops.add(devtype, "-"), "")
      end

      Builtins.y2error("Unknown type: %1", devtype)
      # Device type label
      _("Unknown Network Device")
    end

    def HardwareName(hardware, id)
      return "" if id.nil? || id.empty?
      return "" if hardware.nil? || hardware.empty?

      # filter out a list of hwinfos which correspond to the given id
      res_list = hardware.select do |h|
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

      return "" if provider.nil? || provider == ""

      Provider.Select(provider)
      nam = Ops.get_string(Provider.Current, "PROVIDER", provider)
      return provider if nam.nil? || nam == ""
      nam
    end

    def DeviceStatus(devtype, devname, devmap)
      devmap = deep_copy(devmap)
      # Modem and DSL
      if devtype == "ppp" || devtype == "modem" || devtype == "dsl"
        nam = ProviderName(Ops.get_string(devmap, "PROVIDER", ""))

        # Modem status (%1 is device)
        return Builtins.sformat(_("Configured as %1"), devname) if nam == "" || nam.nil?

        # Modem status (%1 is device, %2 is provider)
        return Builtins.sformat(
          _("Configured as %1 with provider %2"),
          devname,
          nam
        )
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

      else

        proto = Ops.get_string(devmap, "BOOTPROTO", "static")

        if proto == "" || proto == "static" || proto == "none" || proto.nil?
          addr = Ops.get_string(devmap, "IPADDR", "")
          host = NetHwDetection.ResolveIP(addr)
          remip = Ops.get_string(devmap, "REMOTE_IPADDR", "")
          return _("Configured without address (NONE)").dup if proto == "none"
          # Network card status
          return HTML.Colorize(_("Configured without an address"), "red") if IsEmpty(addr)
          if remip == "" || remip.nil?
            # Network card status (%1 is address)
            return Builtins.sformat(_("Configured with address %1"),
              Ops.add(addr, String.OptParens(host)))
          end

          # Network card status (%1 is address, %2 is address)
          return Builtins.sformat(
            _("Configured with address %1 (remote %2)"),
            addr,
            remip
          )
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
        if proto == "" || proto == "static" || proto == "none" || proto.nil?
          addr = Ops.get_string(devmap, "IPADDR", "")
          remip = Ops.get_string(devmap, "REMOTE_IPADDR", "")
          # Network card status (%1 is device)
          return Builtins.sformat(_("Configured as %1"), devname) if addr == "" || addr.nil?

          if remip == "" || remip.nil?
            # Network card status (%1 is device, %2 is address)
            return Builtins.sformat(_("Configured as %1 with address %2"), devname, addr)
          end

          # Network card status (%1 is device, %2 is address, %3 is address)
          return Builtins.sformat(
            _("Configured as %1 with address %2 (remote %3)"),
            devname,
            addr,
            remip
          )
        end

        # Network card status (%1 is device, %2 is protocol)
        return Builtins.sformat(
          _("Configured as %1 with %2"),
          devname,
          Builtins.toupper(proto)
        )
      end
    end

    # Return the device protocol or IP address in case of static config
    # Or indicate that NetworkManager takes over.
    # @param [Hash] devmap device map
    # @return textual device protocol
    def DeviceProtocol(devmap)
      return _("Not configured") if devmap.nil? || devmap.empty?
      # Abbreviation for "The interface is Managed by NetworkManager"
      return _("Managed") if devmap["STARTMODE"] == "managed"

      bootproto = devmap["BOOTPROTO"] || "static"

      if bootproto.empty? || bootproto == "static"
        return "NONE" if devmap["IPADDR"] == "0.0.0.0"

        devmap["IPADDR"].to_s
      else
        bootproto.upcase
      end
    end
  end
end
