require "yast"
require "cwm/custom_widget"

require "y2network/interface_type"

Yast.import "DNS"
Yast.import "Hostname"
Yast.import "IP"
Yast.import "Label"
Yast.import "Netmask"
Yast.import "NetHwDetection"
Yast.import "Popup"
Yast.import "ProductFeatures"
Yast.import "UI"

module Y2Network
  module Widgets
    class BootProtocol < CWM::CustomWidget
      def initialize(settings)
        textdomain "network"
        @settings = settings
      end

      def contents
        RadioButtonGroup(
          Id(:bootproto),
          VBox(
            Left(
              HBox(
                RadioButton(
                  Id(:bootproto_none),
                  Opt(:notify),
                  _("No Link and IP Setup (Bonding Slaves)")
                ),
                HSpacing(1),
                ReplacePoint(
                  Id(:bootproto_rp),
                  CheckBox(Id(:bootproto_ibft), Opt(:notify), _("Use iBFT Values"))
                )
              )
            ),
            Left(
              HBox(
                RadioButton(Id(:bootproto_dynamic), Opt(:notify), _("Dynamic Address")),
                HSpacing(2),
                ComboBox(
                  Id(:bootproto_dyn),
                  Opt(:notify),
                  "",
                  [
                    Item(Id(:bootproto_dhcp), "DHCP"),
                    Item(Id(:bootproto_dhcp_auto), "DHCP+Zeroconf"),
                    Item(Id(:bootproto_auto), "Zeroconf")
                  ]
                ),
                HSpacing(2),
                ComboBox(
                  Id(:bootproto_dhcp_mode),
                  "",
                  [
                    Item(Id(:bootproto_dhcp_both), _("DHCP both version 4 and 6")),
                    Item(Id(:bootproto_dhcp_v4), _("DHCP version 4 only")),
                    Item(Id(:bootproto_dhcp_v6), _("DHCP version 6 only"))
                  ]
                )
              )
            ),
            VBox(
              Left(
                RadioButton(
                  Id(:bootproto_static),
                  Opt(:notify),
                  _("Statically Assigned IP Address")
                )
              ),
              HBox(
                # TODO: When object CWM top level is used, then use here IPAddress object
                InputField(Id(:bootproto_ipaddr), Opt(:hstretch), _("&IP Address")),
                HSpacing(1),
                InputField(Id(:bootproto_netmask), Opt(:hstretch), _("&Subnet Mask")),
                HSpacing(1),
                InputField(Id(:bootproto_hostname), Opt(:hstretch), _("&Hostname")),
                HStretch()
              )
            )
          )
        )
      end

      def ibft_available?
        # IBFT only for eth, is it correct?
        @settings.type == Y2Network::InterfaceType::ETHERNET
      end

      def init
        if !ibft_available?
          Yast::UI.ReplaceWidget(
            :bootproto_rp,
            Empty()
          )
        end

        case @settings["BOOTPROTO"]
        when "static"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_static)
          Yast::UI.ChangeWidget(
            Id(:bootproto_ipaddr),
            :Value,
            @settings["IPADDR"] || ""
          )
          if @settings["PREFIXLEN"] && !@settings["PREFIXLEN"].empty?
            Yast::UI.ChangeWidget(
              Id(:bootproto_netmask),
              :Value,
              "/#{@settings["PREFIXLEN"]}"
            )
          else
            Yast::UI.ChangeWidget(
              Id(:bootproto_netmask),
              :Value,
              @settings["NETMASK"] || ""
            )
          end
          Yast::UI.ChangeWidget(
            Id(:bootproto_hostname),
            :Value,
            @settings["HOSTNAME"]
          )
        when "dhcp"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_dynamic)
          Yast::UI.ChangeWidget(Id(:bootproto_dhcp_mode), :Value, :bootproto_dhcp_both)
          Yast::UI.ChangeWidget(Id(:bootproto_dyn), :Value, :bootproto_dhcp)
        when "dhcp4"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_dynamic)
          Yast::UI.ChangeWidget(Id(:bootproto_dhcp_mode), :Value, :bootproto_dhcp_v4)
          Yast::UI.ChangeWidget(Id(:bootproto_dyn), :Value, :bootproto_dhcp)
        when "dhcp6"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_dynamic)
          Yast::UI.ChangeWidget(Id(:bootproto_dhcp_mode), :Value, :bootproto_dhcp_v6)
          Yast::UI.ChangeWidget(Id(:bootproto_dyn), :Value, :bootproto_dhcp)
        when "dhcp+autoip"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_dynamic)
          Yast::UI.ChangeWidget(Id(:bootproto_dyn), :Value, :bootproto_dhcp_auto)
        when "autoip"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_dynamic)
          Yast::UI.ChangeWidget(Id(:bootproto_dyn), :Value, :bootproto_auto)
        when "none"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_none)
        when "ibft"
          Yast::UI.ChangeWidget(Id(:bootproto), :CurrentButton, :bootproto_none)
          Yast::UI.ChangeWidget(Id(:bootproto_ibft), :Value, true)
        end

        handle
      end

      def handle
        case value
        when :bootproto_static
          static_enabled(true)
          dynamic_enabled(false)
          none_enabled(false)
          one_ip = Yast::UI.QueryWidget(Id(:bootproto_ipaddr), :Value)
          if one_ip.empty?
            log.info "Presetting global hostname"
            Yast::UI.ChangeWidget(
              Id(:bootproto_hostname),
              :Value,
              Yast::Hostname.MergeFQ(Yast::DNS.hostname, Yast::DNS.domain)
            )
          end
        when :bootproto_dynamic
          static_enabled(false)
          dynamic_enabled(true)
          none_enabled(false)
        when :bootproto_none
          static_enabled(false)
          dynamic_enabled(false)
          none_enabled(true)
        else
          raise "Unexpected value for boot protocol #{value.inspect}"
        end

        nil
      end

      def store
        # FIXME: this value reset should be in backend in general not Yast::UI responsibility
        @settings["IPADDR"] = @settings["NETMASK"] = @settings["PREFIXLEN"] = ""
        case value
        when :bootproto_none
          bootproto = "none"
          if ibft_available?
            bootproto = Yast::UI.QueryWidget(Id(:bootproto_ibft), :Value) ? "ibft" : "none"
          end
          @settings["BOOTPROTO"] = bootproto
        when :bootproto_static
          @settings["BOOTPROTO"] = "static"
          @settings["IPADDR"] = Yast::UI.QueryWidget(:bootproto_ipaddr, :Value)
          mask = Yast::UI.QueryWidget(:bootproto_netmask, :Value)
          if mask.start_with?("/")
            @settings["PREFIXLEN"] = mask[1..-1]
          else
            param = Yast::Netmask.Check6(mask) ? "PREFIXLEN" : "NETMASK"
            @settings[param] = mask
          end
          @settings["HOSTNAME"] = Yast::UI.QueryWidget(:bootproto_hostname, :Value)
        when :bootproto_dynamic
          case Yast::UI.QueryWidget(:bootproto_dyn, :Value)
          when :bootproto_dhcp
            case Yast::UI.QueryWidget(:bootproto_dhcp_mode, :Value)
            when :bootproto_dhcp_both
              @settings["BOOTPROTO"] = "dhcp"
            when :bootproto_dhcp_v4
              @settings["BOOTPROTO"] = "dhcp4"
            when :bootproto_dhcp_v6
              @settings["BOOTPROTO"] = "dhcp6"
            else
              raise "Unexpected dhcp mode value #{Yast::UI.QueryWidget(:bootproto_dhcp_mode, :Value).inspect}"
            end
          when :bootproto_dhcp_auto
            @settings["BOOTPROTO"] = "dhcp+autoip"
          when :bootproto_auto
            @settings["BOOTPROTO"] = "autoip"
          else
            raise "Unexpected dynamic mode value #{Yast::UI.QueryWidget(:bootproto_dyn, :Value).inspect}"
          end
        else
          raise "Unexpected boot protocol value #{Yast::UI.QueryWidget(:bootproto, :Value).inspect}"
        end
      end

      def validate
        return true if value != :bootproto_static

        ipa = Yast::UI.QueryWidget(:bootproto_ipaddr, :Value)
        if !Yast::IP.Check(ipa)
          Yast::Popup.Error(_("No valid IP address."))
          Yast::UI.SetFocus(:bootproto_ipaddr)
          return false
        end

        mask = Yast::UI.QueryWidget(:bootproto_netmask, :Value)
        if mask != "" && !valid_netmask(ipa, mask)
          Yast::Popup.Error(_("No valid netmask or prefix length."))
          Yast::UI.SetFocus(:bootproto_netmask)
          return false
        end

        hname = Yast::UI.QueryWidget(:bootproto_hostname, :Value)
        if !hname.empty?
          if !Yast::Hostname.CheckFQ(hname)
            Popup.Error(_("Invalid hostname."))
            Yast::UI.SetFocus(:bootproto_hostname)
            return false
          end
        # There'll be no 127.0.0.2 -> remind user to define some hostname
        elsif !Yast::Host.NeedDummyIP &&
            !Yast::Popup.YesNo(
              _(
                "No hostname has been specified. We recommend to associate \n" \
                  "a hostname with a static IP, otherwise the machine name will \n" \
                  "not be resolvable without an active network connection.\n" \
                  "\n" \
                  "Really leave the hostname blank?\n"
              )
            )
          Yast::UI.SetFocus(:bootproto_hostname)
          return false
        end

        # validate duplication
        if Yast::NetHwDetection.DuplicateIP(ipa)
          Yast::UI.SetFocus(:bootproto_ipaddr)
          # Popup text
          if !Yast::Popup.YesNoHeadline(
            Yast::Label.WarningMsg,
            _("Duplicate IP address detected.\nReally continue?\n")
          )
            return false
          end
        end

        true
      end

      def help
        res = _(
          "<p><b><big>Address Setup</big></b></p>\n" \
            "<p>Select <b>No Address Setup</b> if you do not want to assign an IP address to this device.\n" \
            "This is particularly useful for bonding ethernet devices.</p>\n"
        ) +
          # FIXME: old CWM does not allow this, but for future this should be dynamic and printed only if iBFT is available
          # and future means when type cannot be changed and when cwm object tabs are used, as it has limited lifetime of cwm definition
          _(
            "<p>Check <b>iBFT</b> if you want to keep the network configured in your BIOS.</p>\n"
          ) +
          # Address dialog help 2/8
          _(
            "<p>Select <b>Dynamic Address</b> if you do not have a static IP address \nassigned by the system administrator or your Internet provider.</p>\n"
          ) +
          # Address dialog help 3/8
          _(
            "<p>Choose one of the dynamic address assignment methods. Select <b>DHCP</b>\n" \
              "if you have a DHCP server running on your local network. Network addresses \n" \
              "are then automatically obtained from the server.</p>\n"
          ) +
          # Address dialog help 4/8
          _(
            "<p>To search for an IP address and assign it statically, select \n" \
              "<b>Zeroconf</b>. To use DHCP and fall back to zeroconf, select <b>DHCP + Zeroconf\n" \
              "</b>. Otherwise, the network addresses must be assigned <b>Statically</b>.</p>\n"
          )

        if Yast::ProductFeatures.GetBooleanFeature("network", "force_static_ip")
          res += _(
            "<p>DHCP configuration is not recommended for this product.\nComponents of this product might not work with DHCP.</p>"
          )
        end

        res
      end

      def dynamic_enabled(value)
        Yast::UI.ChangeWidget(Id(:bootproto_dyn), :Enabled, value)
        if value
          # dhcp mode works only with plain dhcp
          if :bootproto_dhcp == Yast::UI.QueryWidget(Id(:bootproto_dyn), :Value)
            Yast::UI.ChangeWidget(Id(:bootproto_dhcp_mode), :Enabled, value)
          else
            Yast::UI.ChangeWidget(Id(:bootproto_dhcp_mode), :Enabled, false)
          end
        else
          Yast::UI.ChangeWidget(Id(:bootproto_dhcp_mode), :Enabled, value)
        end
      end

      def none_enabled(value)
        Yast::UI.ChangeWidget(Id(:bootproto_ibft), :Enabled, value) if ibft_available?
      end

      def static_enabled(value)
        Yast::UI.ChangeWidget(Id(:bootproto_ipaddr), :Enabled, value)
        Yast::UI.ChangeWidget(Id(:bootproto_netmask), :Enabled, value)
        Yast::UI.ChangeWidget(Id(:bootproto_hostname), :Enabled, value)
      end

      def value
        Yast::UI.QueryWidget(Id(:bootproto), :CurrentButton)
      end

      def valid_netmask(ip, mask)
        valid_mask = false
        mask = mask[1..-1] if mask.start_with?("/")

        if Yast::IP.Check4(ip) && (Yast::Netmask.Check4(mask) || Yast::Netmask.CheckPrefix4(mask))
          valid_mask = true
        elsif Yast::IP.Check6(ip) && Yast::Netmask.Check6(mask)
          valid_mask = true
        else
          log.warn "IP address #{ip} is not valid"
        end
        valid_mask
      end
    end
  end
end
