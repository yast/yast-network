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
# File:  include/network/complex.ycp
# Package:  Network configuration
# Summary:  Summary and overview functions
# Authors:  Michal Svec <msvec@suse.cz>
#
#
module Yast
  module NetworkComplexInclude
    def initialize_network_complex(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "NetworkInterfaces"

      Yast.include include_target, "network/routines.rb"
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
