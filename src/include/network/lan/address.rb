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
# File:	include/network/lan/address.ycp
# Package:	Network configuration
# Summary:	Network card adresss configuration dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
require "y2firewall/helpers/interfaces"
require "y2network/dialogs/edit_interface"

module Yast
  module NetworkLanAddressInclude
    include Y2Firewall::Helpers::Interfaces
    include Yast::Logger
    include Yast::I18n

    def initialize_network_lan_address(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Host"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "String"

      Yast.include include_target, "network/summary.rb"
      Yast.include include_target, "network/lan/help.rb"
      Yast.include include_target, "network/lan/hardware.rb"
      Yast.include include_target, "network/complex.rb"
      Yast.include include_target, "network/lan/bridge.rb"
      Yast.include include_target, "network/lan/s390.rb"

      @force_static_ip = ProductFeatures.GetBooleanFeature(
        "network",
        "force_static_ip"
      )
    end

    # Dialog for setting up IP address
    # @return dialog result
    def AddressDialog(builder:)
      @builder = builder

      ret = Y2Network::Dialogs::EditInterface.run(builder)
      log.info "ShowAndRun: #{ret}"

      if ret != :back && ret != :abort
        bootproto = builder["BOOTPROTO"]
        ipaddr = builder["IPADDR"]

        # IP is mandatory for static configuration. Makes no sense to write static
        # configuration without that.
        return ret if bootproto == "static" && ipaddr.empty?

        if bootproto == "static"
          update_hostname(ipaddr, builder["HOSTNAME"] || "")
        elsif LanItems.isCurrentDHCP && !LanItems.isCurrentHotplug
          # fixed bug #73739 - if dhcp is used, dont set default gw statically
          # but also: reset default gw only if DHCP* is used, this branch covers
          #		 "No IP address" case, then default gw must stay (#460262)
          # and also: don't delete default GW for usb/pcmcia devices (#307102)
          if LanItems.isCurrentDHCP && !LanItems.isCurrentHotplug
            yast_config = Y2Network::Config.find(:yast)
            if yast_config && yast_config.routing && yast_config.routing.default_route
              remove_gw = Popup.YesNo(
                _(
                  "A static default route is defined.\n" \
                  "It is suggested to remove the static default route definition \n" \
                  "if one can be obtained also via DHCP.\n" \
                  "Do you want to remove the static default route?"
                )
              )
              yast_config.routing.remove_default_routes if remove_gw
            end
          end
        end

        # When virtual interfaces are added the list of routing devices needs
        # to be updated to offer them
        LanItems.add_device_to_routing if LanItems.update_routing_devices?
      end

      # rollback if changes are canceled, as still some widgets edit LanItems directly
      LanItems.Rollback if ret != :next
      # proceed with WLAN settings if appropriate, #42420
      ret = :wire if ret == :next && builder.type.wireless?

      log.info "AddressDialog res: #{ret.inspect}"
      ret
    end

  private

    # Performs hostname update
    #
    # This handles ip and hostname change when editing NIC properties.
    # The method relies on old NIC's IP which is set globally at initialization
    # of NIC edit dialog (@see LanItems#ipaddr)
    #
    # When hostname is empty, then old IP's record is cleared from /etc/hosts and
    # new is not created.
    # Otherwise the canonical name and all aliases in the record
    # are replaced by new ones.
    #
    # @param ipaddr [String] ip address
    # @param hostname [String] new hostname
    def update_hostname(ipaddr, hostname)
      ip_changed = LanItems.ipaddr != ipaddr
      initial_hostname = initial_hostname(LanItems.ipaddr)
      hostname_changed = initial_hostname != hostname

      return if !(ip_changed || hostname_changed || hostname.empty?)

      # store old names, remove the record
      names = Host.names(LanItems.ipaddr).first
      Host.remove_ip(LanItems.ipaddr)

      if ip_changed && !hostname_changed && !names.nil?
        log.info("Dropping record for #{LanItems.ipaddr} from /etc/hosts")

        Host.add_name(ipaddr, names)
      end
      if !hostname.empty? && hostname_changed
        log.info("Updating cannonical name for #{LanItems.ipaddr} in /etc/hosts")

        Host.Update(initial_hostname, hostname, ipaddr)
      end

      nil
    end

    # Returns canonical hostname for the given ip
    def initial_hostname(ipaddr)
      host_list = Host.names(ipaddr)
      if Ops.greater_than(Builtins.size(host_list), 1)
        Builtins.y2milestone(
          "More than one hostname for single IP detected, using the first one only"
        )
      end

      String.FirstChunk(Ops.get(host_list, 0, ""), " \t")
    end
  end
end
