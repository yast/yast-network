require "yast"
require "cwm/custom_widget"

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
        refresh_table
      end

      def refresh_table
        table_items = @settings.aliases.each_with_index.map do |data, i|

          mask = data[:prefixlen].empty? ? data[:mask] : "/#{data[:prefixlen]}"
          Item(Id(i), data[:label], data[:ip], mask)
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
          item = dialog(@settings.name, @settings.aliases[cur])
          if item
            @settings.aliases[cur] = item
            refresh_table
            Yast::UI.ChangeWidget(Id(:address_table), :CurrentItem, cur)
          end
        when :add_address
          item = dialog(@settings.name, nil)
          if item
            @settings.aliases << item
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

      # Open a dialog to edit a name-ipaddr-netmask triple.
      # TODO: own class for it
      # @param name  [String]     device name. Used to ensure label is not too long
      # @param entry [Yast::Term] an existing entry to be edited, or term(:empty)
      # @return      [Yast::Term] a table item for OK, nil for Cancel
      def dialog(name, entry)
        label = entry ? entry[:label] : ""
        ip = entry ? entry[:ip] : ""
        mask = if entry
          entry[:prefixlen].empty? ? entry[:mask] : "/#{entry[:prefixlen]}"
        else
          ""
        end
        Yast::UI.OpenDialog(
          Opt(:decorated),
          VBox(
            HSpacing(1),
            VBox(
              # TextEntry label
              TextEntry(Id(:name), _("&Address Label"), label),
              # TextEntry label
              TextEntry(
                Id(:ipaddr),
                _("&IP Address"),
                ip
              ),
              # TextEntry label
              TextEntry(Id(:netmask), _("Net&mask"), mask)
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

        if entry
          Yast::UI.SetFocus(Id(:ipaddr))
        else
          Yast::UI.SetFocus(Id(:name))
        end

        while (ret = Yast::UI.UserInput) == :ok

          res = {}
          val = Yast::UI.QueryWidget(Id(:name), :Value)

          if "#{name}.#{val}" !~ /^[[:alnum:]._:-]{1,15}\z/
            # Popup::Error text
            Yast::Popup.Error(_("Label is too long."))
            Yast::UI.SetFocus(Id(:name))
            next
          end

          res[:label] = val

          ip = Yast::UI.QueryWidget(Id(:ipaddr), :Value)
          if !Yast::IP.Check(ip)
            # Popup::Error text
            Yast::Popup.Error(_("The IP address is invalid."))
            Yast::UI.SetFocus(Id(:ipaddr))
            next
          end
          res[:ip] = ip

          val = Yast::UI.QueryWidget(Id(:netmask), :Value)
          if !valid_prefix_or_netmask(ip, val)
            # Popup::Error text
            Yast::Popup.Error(_("The subnet mask is invalid."))
            Yast::UI.SetFocus(Id(:netmask))
            next
          end
          netmask = ""
          prefixlen = ""
          if val.start_with?("/")
            prefixlen = val[1..-1]
          elsif Yast::Netmask.Check6(val)
            prefixlen = val
          else
            netmask = val
          end
          res[:mask] = netmask
          res[:prefixlen] = prefixlen

          break
        end

        Yast::UI.CloseDialog
        return nil if ret != :ok

        res
      end

      def valid_prefix_or_netmask(ip, mask)
        valid_mask = false
        mask = mask[1..-1] if mask.start_with?("/")

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
