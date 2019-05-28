require "yast"
require "cwm/custom_widget"

Yast.import "NetworkService"
Yast.import "LanItems"
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
           "<p><b><big>Additional Addresses</big></b></p>\n<p>Configure additional addresses of an interface in this table.</p>\n"
         ) +
           # Aliases dialog help 2/4
           _(
             "<p>Enter an <b>IPv4 Address Label</b>, an <b>IP Address</b>, and\nthe <b>Netmask</b>.</p>"
           ) +
           # Aliases dialog help 3/4
           _(
             "<p><b>IPv4 Address Label</b>, formerly known as Alias Name, is optional and legacy. The total\n" \
             "length of interface name (inclusive of the colon and label) is\n" \
             "limited to 15 characters. The obsolete ifconfig utility truncates it after 9 characters.</p>"
           ) +
           # Aliases dialog help 3/4, #83766
           _(
             "<p>Do not include the interface name in the label. For example, enter <b>foo</b> instead of <b>eth0:foo</b>.</p>"
           )
      end

      def init
        # #165059
        if Yast::NetworkService.is_network_manager
          Yast::UI.ChangeWidget(:additional_addresses, :Enabled, false)
        end

        table_items = []
        # make ui items from the aliases list
        # TODO: Do not touch Lan Items
        Yast::LanItems.aliases.each_value do |data|
          label = data["LABEL"] || ""
          ip = data["IPADDR"] ||  ""
          mask = data["NETMASK"] || ""
          prefixlen = data["PREFIXLEN"] || ""
          if !prefixlen.empty?
            mask = "/#{prefixlen}"
          end
          table_items << Item(Id(table_items.size), label, ip, mask)
        end

        Yast::UI.ChangeWidget(Id(:address_table), :Items, table_items)
      end

      # @return [Symbol, nil] dialog result
      def handle(event)
        return nil if Yast::NetworkService.is_network_manager

        table_items = Yast::UI.QueryWidget(Id(:address_table), :Items)

        return nil if event["EventReason"] != "Activated"

        cur = Yast::UI.QueryWidget(Id(:address_table), :CurrentItem).to_i
        case event["ID"]
        when :edit_address
          item = dialog(cur, table_items[cur])
          if item
            table_items[cur] = item
            Yast::UI.ChangeWidget(Id(:address_table), :Items, table_items)
            Yast::UI.ChangeWidget(Id(:address_table), :CurrentItem, cur)
          end
        when :add_address
          item = dialog(table_items.size, Yast::Term.new(:empty))
          if item
            table_items << item
            Yast::UI.ChangeWidget(Id(:address_table), :Items, table_items)
            Yast::UI.ChangeWidget(
              Id(:address_table),
              :CurrentItem,
              table_items.size
            )
          end
        when :delete_address
          table_items.delete_at(cur)
          Yast::UI.ChangeWidget(Id(:address_table), :Items, table_items)
        end

        Yast::UI.ChangeWidget(
          Id(:edit_address),
          :Enabled,
          !table_items.empty?
        )
        Yast::UI.ChangeWidget(
          Id(:delete_address),
          :Enabled,
          !table_items.empty?
        )

        nil
      end

      def store
        return if Yast::NetworkService.is_network_manager

        table_items = Yast::UI.QueryWidget(Id(:address_table), :Items)
        aliases_to_delete = Yast::LanItems.aliases.dup # #48191
        Yast::LanItems.aliases = {}
        table_items.each_with_index do |e, i|
          alias_ = {}
          alias_["IPADDR"] = e.params[2] || ""
          label = e.params[1] || ""
          alias_["LABEL"] = label unless label.empty?

          mask = e.params[3] || ""
          if mask.start_with?("/")
            alias_["PREFIXLEN"] = mask[1..-1]
          else
            param = Yast::Netmask.Check6(mask) ? "PREFIXLEN" : "NETMASK"
            alias_[param] = mask
          end
          Yast::LanItems.aliases[i.to_s] = alias_
        end
        # TODO: this should not be in UI and also deleting looks strange as it remove all old
        aliases_to_delete.each_pair do |a, v|
          Yast::NetworkInterfaces.DeleteAlias(Yast::NetworkInterfaces.Name, a) if !v.nil?
        end
      end

      # Open a dialog to edit a name-ipaddr-netmask triple.
      # TODO: own class for it
      # @param id    [Integer]    an id for the table item to be returned
      # @param entry [Yast::Term] an existing entry to be edited, or term(:empty)
      # @return      [Yast::Term] a table item for OK, nil for Cancel
      def dialog(id, entry)
        Yast::UI.OpenDialog(
          Opt(:decorated),
          VBox(
            HSpacing(1),
            VBox(
              # TextEntry label
              TextEntry(Id(:name), _("&Address Label"), entry.params[1] || ""),
              # TextEntry label
              TextEntry(
                Id(:ipaddr),
                _("&IP Address"),
                entry.params[2] || ""
              ),
              # TextEntry label
              TextEntry(Id(:netmask), _("Net&mask"), entry.params[3] || "")
            ),
            HSpacing(1),
            HBox(
              PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
              PushButton(Id(:cancel), Yast::Label.CancelButton)
            )
          )
        )

        Yast::UI.ChangeWidget(
          Id(:name),
          :ValidChars,
          Yast::String.CAlnum
        )
        Yast::UI.ChangeWidget(Id(:ipaddr), :ValidChars, Yast::IP.ValidChars)

        if entry == Yast::Term.new(:empty)
          Yast::UI.SetFocus(Id(:name))
        else
          Yast::UI.SetFocus(Id(:ipaddr))
        end

        while (ret = Yast::UI.UserInput) == :ok

          host = Item(Id(id))
          val = Yast::UI.QueryWidget(Id(:name), :Value)

          # TODO: not access LanItems
          if "#{Yast::LanItems.device}.#{val}" !~ /^[[:alnum:]._:-]{1,15}\z/
            # Popup::Error text
            Yast::Popup.Error(_("Label is too long."))
            Yast::UI.SetFocus(Id(:name))
            next
          end

          host.params << val

          ip = Yast::UI.QueryWidget(Id(:ipaddr), :Value)
          if !Yast::IP.Check(ip)
            # Popup::Error text
            Yast::Popup.Error(_("The IP address is invalid."))
            Yast::UI.SetFocus(Id(:ipaddr))
            next
          end
          host << ip

          val = Yast::UI.QueryWidget(Id(:netmask), :Value)
          if !valid_prefix_or_netmask(ip, val)
            # Popup::Error text
            Yast::Popup.Error(_("The subnet mask is invalid."))
            Yast::UI.SetFocus(Id(:netmask))
            next
          end
          host << val

          break
        end

        Yast::UI.CloseDialog
        return nil if ret != :ok

        host
      end

      def valid_prefix_or_netmask(ip, mask)
        valid_mask = false
        if mask.start_with?("/")
          mask = mask[1..-1]
        end

        if Yast::IP.Check4(ip) && (Yast::Netmask.Check4(mask) || Yast::Netmask.CheckPrefix4(mask))
          valid_mask = true
        elsif Yast::IP.Check6(ip) && Yast::Netmask.Check6(mask)
          valid_mask = true
        else
          log.warn "IP address #{ip} and mask #{mask} is not valid"
        end
        valid_mask
      end
    end
  end
end
