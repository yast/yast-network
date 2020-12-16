# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "cwm/custom_widget"
require "ipaddr"
require "ostruct"
require "y2network/dialogs/additional_address"

Yast.import "IP"
Yast.import "Popup"
Yast.import "String"

module Y2Network
  module Widgets
    class AdditionalAddresses < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def contents
        Frame(
          Id(:additional_addresses),
          # Frame label
          _("Additional Addresses"),
          HBox(
            HSpacing(3),
            VBox(
              # :-) this is a small trick to make ncurses in 80x25 happy :-)
              # it rounds spacing up or down to the nearest integer, 0.5 -> 1, 0.49 -> 0
              VSpacing(0.49),
              Table(
                Id(:address_table),
                Opt(:notify),
                Header(
                  # Table header label
                  _("Address Label"),
                  # Table header label
                  _("IP Address"),
                  # Table header label
                  _("Netmask")
                ),
                []
              ),
              Left(
                HBox(
                  # PushButton label
                  PushButton(Id(:add_address), _("Ad&d")),
                  # PushButton label
                  PushButton(Id(:edit_address), Opt(:disabled), _("&Edit")),
                  # PushButton label
                  PushButton(Id(:delete_address), Opt(:disabled), _("De&lete"))
                )
              ),
              VSpacing(0.49)
            ),
            HSpacing(3)
          )
        )
      end

      def help
        _(
          "<p><b><big>Additional Addresses</big></b></p>\n" \
            "<p>Configure additional addresses of an interface in this table.</p>\n"
        ) +
          # Aliases dialog help 2/4
          _(
            "<p>Enter an <b>IPv4 Address Label</b>, an <b>IP Address</b>, and\n" \
              "the <b>Netmask</b>.</p>"
          ) +
          # Aliases dialog help 3/4
          _(
            "<p><b>IPv4 Address Label</b>, formerly known as Alias Name, is " \
            "optional and legacy. The total\n" \
            "length of interface name (inclusive of the colon and label) is\n" \
            "limited to 15 characters. The obsolete ifconfig utility truncates " \
            "it after 9 characters.</p>"
          ) +
          # Aliases dialog help 3/4, #83766
          _(
            "<p>Do not include the interface name in the label. For example, " \
              "enter <b>foo</b> instead of <b>eth0:foo</b>.</p>"
          )
      end

      def init
        refresh_table
      end

      def refresh_table
        table_items = @settings.aliases.each_with_index.map do |data, i|
          Item(Id(i), data[:label], data[:ip_address], data[:subnet_prefix])
        end

        Yast::UI.ChangeWidget(Id(:address_table), :Items, table_items)
        Yast::UI.ChangeWidget(
          Id(:edit_address),
          :Enabled,
          !@settings.aliases.empty?
        )
        Yast::UI.ChangeWidget(
          Id(:delete_address),
          :Enabled,
          !@settings.aliases.empty?
        )
      end

      # @return [Symbol, nil] dialog result
      def handle(event)
        return nil if event["EventReason"] != "Activated"

        cur = Yast::UI.QueryWidget(Id(:address_table), :CurrentItem).to_i
        case event["ID"]
        when :edit_address
          ip_settings = settings_for(cur)
          if Dialogs::AdditionalAddress.new(@settings.name, ip_settings).run == :ok
            @settings.aliases[cur] = ip_settings.to_h
            refresh_table
            Yast::UI.ChangeWidget(Id(:address_table), :CurrentItem, cur)
          end
        when :add_address
          ip_settings = settings_for(nil)
          if Dialogs::AdditionalAddress.new(@settings.name, ip_settings).run == :ok
            @settings.aliases << ip_settings.to_h
            refresh_table
            Yast::UI.ChangeWidget(
              Id(:address_table),
              :CurrentItem,
              @settings.aliases.size - 1
            )
          end
        when :delete_address
          @settings.aliases.delete_at(cur)
          refresh_table
        end

        nil
      end

    private

      # Convenience method to obtain an object with the additionl IP address
      # data.
      #
      # @param index [Integer, nil] the position of the alias to be edited or
      #   nil in case a new one is wanted
      # @return [OpenStruct] additional IP address data
      def settings_for(index)
        OpenStruct.new(index ? @settings.aliases[index] : @settings.alias_for(nil))
      end
    end
  end
end
