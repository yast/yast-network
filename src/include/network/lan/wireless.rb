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
# File:	include/network/lan/wizards.ycp
# Package:	Network configuration
# Summary:	Network cards configuration wizards
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkLanWirelessInclude
    def initialize_network_lan_wireless(include_target)
      textdomain "network"

      Yast.import "CWM"
      Yast.import "FileUtils"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "LanItems"
      Yast.import "Map"
      Yast.import "Message"
      Yast.import "Popup"
      Yast.import "String"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/help.rb"

      # key input type buttons
      @type_w = RadioButtonGroup(
        Id(:type_g),
        VBox(
          # Translators: input type for a wireless key
          # radio button group label
          Left(Label(_("Key Input Type"))),
          Left(
            HBox(
              # Translators: input type for a wireless key
              RadioButton(Id("passphrase"), _("&Passphrase")),
              HSpacing(1),
              # Translators: input type for a wireless key
              RadioButton(Id("ascii"), _("&ASCII")),
              HSpacing(1),
              # Translators: input type for a wireless key
              # (Hexadecimal)
              RadioButton(Id("hex"), _("&Hexadecimal"))
            )
          )
        )
      )

      @wpa_eap_widget_descr = {
        "WPA_EAP_MODE"                => {
          "widget" => :combobox,
          # combo box label
          "label"  => _("EAP &Mode"),
          "opt"    => [:notify],
          "items"  => [
            # combo box item, one of WPA EAP modes
            ["TTLS", _("TTLS")],
            # combo box item, one of WPA EAP modes
            ["PEAP", _("PEAP")],
            # combo box item, one of WPA EAP modes
            ["TLS", _("TLS")]
          ],
          "help"   => _(
            "<p>WPA-EAP uses a RADIUS server to authenticate users. There\n" \
              "are different methods in EAP to connect to the server and\n" \
              "perform the authentication, namely TLS, TTLS, and PEAP.</p>\n"
          ),
          "init"   => fun_ref(method(:InitEapMode), "void (string)"),
          "handle" => fun_ref(method(:HandleEapMode), "symbol (string, map)")
        },
        # the four WPA_EAP_* widgets come together, so the helps are
        # dipersed a bit
        "WPA_EAP_IDENTITY"            => {
          "widget" => :textentry,
          # text entry label
          "label"  => _("&Identity"),
          "opt"    => [],
          "help"   => _(
            "<p>For TTLS and PEAP, enter your <b>Identity</b>\n" \
              "and <b>Password</b> as configured on the server.\n" \
              "If you have special requirements to set the username used as\n" \
              "<b>Anonymous Identity</b>, you may set it here. This is usually not needed.</p>\n"
          )
        },
        "WPA_EAP_ANONID"              => {
          "widget" => :textentry,
          # text entry label
          "label"  => _("&Anonymous Identity"),
          "opt"    => [],
          "help"   => ""
        },
        "WPA_EAP_PASSWORD"            => {
          "widget" => :password,
          # or password?
          # text entry label
          "label"  => _("&Password"),
          "opt"    => [],
          "help"   => ""
        },
        "WPA_EAP_CLIENT_CERT"         => {
          "widget"            => :textentry,
          # text entry label
          "label"             => _("&Client Certificate"),
          "opt"               => [],
          "help"              => _(
            "<p>TLS uses a <b>Client Certificate</b> instead of a username and\n" \
              "password combination for authentication. It uses a public and private key pair\n" \
              "to encrypt negotiation communication, therefore you will additionally need\n" \
              "a <b>Client Key</b> file that contains your private key and\n" \
              "the appropriate <b>Client Key Password</b> for that file.</p>\n"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateFileExists),
            "boolean (string, map)"
          )
        },
        "WPA_EAP_CLIENT_KEY"          => {
          "widget"            => :textentry,
          # text entry label
          "label"             => _("Client &Key"),
          "opt"               => [],
          "help"              => "",
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateFileExists),
            "boolean (string, map)"
          )
        },
        "WPA_EAP_CLIENT_KEY_PASSWORD" => {
          "widget" => :textentry,
          # or password?
          # text entry label
          "label"  => _(
            "Client Key Pass&word"
          ),
          "opt"    => [],
          "help"   => ""
        },
        "WPA_EAP_CA_CERT"             => {
          "widget"            => :textentry,
          # text entry label
          # aka certificate of the CA (certification authority)
          "label"             => _(
            "&Server Certificate"
          ),
          "opt"               => [],
          "help"              => _(
            "<p>To increase security, it is recommended to configure\n" \
              "a <b>Server Certificate</b>. It is used\n" \
              "to validate the server's authenticity.</p>\n"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateCaCertExists),
            "boolean (string, map)"
          )
        },
        "WPA_EAP_CLIENT_CERT_BROWSE"  => {
          "widget" => :push_button,
          "label"  => "...",
          "opt"    => [:autoShortcut],
          "help"   => "",
          "init"   => fun_ref(CWM.method(:InitNull), "void (string)"),
          "store"  => fun_ref(CWM.method(:StoreNull), "void (string, map)"),
          "handle" => fun_ref(method(:HandleFileBrowse), "symbol (string, map)")
        },
        "WPA_EAP_CLIENT_KEY_BROWSE"   => {
          "widget" => :push_button,
          "label"  => "...",
          "opt"    => [:autoShortcut],
          "help"   => "",
          "init"   => fun_ref(CWM.method(:InitNull), "void (string)"),
          "store"  => fun_ref(CWM.method(:StoreNull), "void (string, map)"),
          "handle" => fun_ref(method(:HandleFileBrowse), "symbol (string, map)")
        },
        "WPA_EAP_CA_CERT_BROWSE"      => {
          "widget" => :push_button,
          "label"  => "...",
          "opt"    => [:autoShortcut],
          "help"   => "",
          "init"   => fun_ref(CWM.method(:InitNull), "void (string)"),
          "store"  => fun_ref(CWM.method(:StoreNull), "void (string, map)"),
          "handle" => fun_ref(method(:HandleFileBrowse), "symbol (string, map)")
        },
        "DETAILS_B"                   => {
          "widget" => :push_button,
          # push button label
          "label"  => _("&Details"),
          "opt"    => [],
          "help"   => "",
          "init"   => fun_ref(CWM.method(:InitNull), "void (string)"),
          "store"  => fun_ref(CWM.method(:StoreNull), "void (string, map)"),
          "handle" => fun_ref(method(:HandleDetails), "symbol (string, map)")
        },
        "WPA_EAP_DUMMY"               => {
          "widget"            => :empty,
          "help"              => _(
            "If you do not know your ID and password or you do not have\nany certificate or key files, contact your system administrator.\n"
          ),
          "init"              => fun_ref(CWM.method(:InitNull), "void (string)"),
          "store"             => fun_ref(
            CWM.method(:StoreNull),
            "void (string, map)"
          ),
          "validate_type"     => :function,
          "validate_function" => fun_ref(
            method(:ValidateWpaEap),
            "boolean (string, map)"
          )
        },
        # Details dialog
        "WPA_EAP_AUTH"                => {
          "widget" => :combobox,
          # combo box label
          "label"  => _("&Authentication Method"),
          "help"   => _(
            "<p>Here you can configure the inner authentication (also known as phase 2)\n" \
              "method. By default, all methods are allowed. If you want to restrict the\n" \
              "allowed methods or in case you have encountered difficulties regarding\n" \
              "authentication, choose your inner authentication method.</p>\n"
          )
        },
        "WPA_EAP_PEAP_VERSION"        => {
          "widget" => :radio_buttons,
          # radio button group label
          "label"  => _("&PEAP Version"),
          "help"   => _(
            "<p>If you are using PEAP, you can also force the use of a specific PEAP\nimplementation (version 0 or 1). Normally this should not be necessary.</p>\n"
          ),
          "items"  => [
            # radio button: any version of PEAP
            ["", _("&Any")],
            ["0", "&0"],
            ["1", "&1"]
          ],
          "init"   => fun_ref(method(:InitPeapVersion), "void (string)")
        }
      }
    end

    # Compose a typed key into a single-string representation
    # @param [String] type "passphrase", "ascii", "hex"
    # @param [String] key
    # @return prefixed key
    def ComposeWepKey(type, key)
      # prefixes for key types
      prefix = { "ascii" => "s:", "passphrase" => "h:", "hex" => "" }

      # empty key - don't prepend a type (#40431)
      key == "" ? "" : Ops.add(Ops.get(prefix, type, "?:"), key)
    end

    def ParseWepKey(tkey)
      if Builtins.substring(tkey, 0, 2) == "s:"
        { "key" => Builtins.substring(tkey, 2), "type" => "ascii" }
      elsif Builtins.substring(tkey, 0, 2) == "h:"
        { "key" => Builtins.substring(tkey, 2), "type" => "passphrase" }
      # make passphrase the default key type, #40431
      elsif tkey == ""
        { "key" => tkey, "type" => "passphrase" }
      else
        { "key" => tkey, "type" => "hex" }
      end
    end

    # Is the entered key valid?
    # TODO: check according to the selected key length
    # (or better adjust the length?)
    # @param [Array<Fixnum>] lengths allowed real key lengths
    def CheckWirelessKey(key, lengths)
      lengths = deep_copy(lengths)
      return false if key.nil?

      if Builtins.regexpmatch(key, "^s:.{5}$") && Builtins.contains(lengths, 40) ||
          Builtins.regexpmatch(key, "^s:.{6,13}$") &&
              Builtins.contains(lengths, 104)
        return true
      end

      if Builtins.regexpmatch(key, "^[0-9A-Fa-f-]*$")
        key = Builtins.deletechars(key, "-")
        actual_bits = Ops.multiply(Builtins.size(key), 4) # 4 bits per hex digit
        return true if Builtins.contains(lengths, actual_bits)
        Builtins.y2milestone(
          "Key length: actual %1, allowed %2",
          actual_bits,
          lengths
        )
      end

      return true if Builtins.regexpmatch(key, "^h:")

      false
    end

    # Takes the WEP items from the list and returns the key lengths as integers
    # Like the input, uses the real length which is 24 bits shorter
    # than the marketing one.
    # If the input is nil, return the default set of key lengths.
    # @param [Array<String>] enc_modes a subset of WEP40, WEP104, WEP128, WEP232, TKIP, CCMP
    # @return [Array] of real key lengths
    def ParseKeyLengths(enc_modes)
      enc_modes = deep_copy(enc_modes)
      return [40, 104] if enc_modes.nil?

      lengths = []
      Builtins.foreach(enc_modes) do |em|
        if Builtins.substring(em, 0, 3) == "WEP"
          lengths = Builtins.add(
            lengths,
            Builtins.tointeger(Builtins.substring(em, 3))
          )
        end
      end

      Builtins.y2warning("empty set of key lengths") if lengths == []
      deep_copy(lengths)
    end

    # Make a list of ComboBox items for authentication mode.
    # We must translate WPA-PSK: it is "wpa-psk" in hwinfo but "psk" in syconfig
    # (#74496).
    # @param [Array<String>] authmodes allowed modes as returned by hwinfo. nil == don't know.
    # @return combo box items
    def AuthModeItems(authmodes)
      authmodes = deep_copy(authmodes)
      names = {
        # Wireless authentication modes:
        # ComboBox item
        "no-encryption" => _(
          "No Encryption"
        ),
        # ComboBox item
        "open"          => _("WEP - Open"),
        # ComboBox item
        "sharedkey"     => _("WEP - Shared Key"),
        # ComboBox item
        # Ask me what it means, I don't know yet
        "wpa-psk"       => _(
          "WPA-PSK (WPA version 1 or 2)"
        ),
        # ComboBox item
        "wpa-eap"       => _("WPA-EAP (WPA version 1 or 2)")
      }
      ids = { "wpa-psk" => "psk", "wpa-eap" => "eap" }
      authmodes = if authmodes.nil?
        Convert.convert(
          Map.Keys(names),
          from: "list",
          to:   "list <string>"
        )
      else
        # keep only those that we know how to handle
        Builtins.filter(authmodes) do |am|
          Builtins.haskey(names, am)
        end
      end
      Builtins.maplist(authmodes) do |am|
        Item(Id(Ops.get(ids, am, am)), Ops.get(names, am, am))
      end
    end

    # Wireless devices configuration dialog
    # @return dialog result
    def WirelessDialog
      # Wireless dialog caption
      caption = _("Wireless Network Card Configuration")
      mode = LanItems.wl_mode
      essid = LanItems.wl_essid
      authmode = LanItems.wl_auth_mode
      # wpa or wep?
      authmode_wpa = authmode == "psk" || authmode == "eap" # shortcut
      key = nil
      type = nil
      if authmode == "psk"
        key = LanItems.wl_wpa_psk
        type = Builtins.size(key) == 64 ? "hex" : "passphrase"
      elsif authmode != "eap"
        wkey = ParseWepKey(
          Ops.get(LanItems.wl_key, LanItems.wl_default_key, "")
        )
        key = Ops.get(wkey, "key", "")
        type = Ops.get(wkey, "type", "")
      else
        key = "" # and type is not used
      end

      key_lengths = ParseKeyLengths(LanItems.wl_enc_modes)

      # Wireless dialog contents
      contents = HBox(
        HSpacing(4),
        VBox(
          VSpacing(0.5),
          # Frame label
          Frame(
            _("Wireless Device Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(0.5),
                # ComboBox label
                ComboBox(
                  Id(:mode),
                  Opt(:hstretch),
                  _("O&perating Mode"),
                  [
                    # ComboBox item
                    Item(Id("Ad-hoc"), _("Ad-Hoc"), mode == "Ad-hoc"),
                    # ComboBox item
                    Item(Id("Managed"), _("Managed"), mode == "Managed"),
                    # ComboBox item
                    Item(Id("Master"), _("Master"), mode == "Master")
                  ]
                ),
                VSpacing(0.2),
                # Text entry label
                HBox(
                  ComboBox(
                    Id(:essid),
                    Opt(:editable),
                    _("Ne&twork Name (ESSID)"),
                    [essid]
                  ),
                  PushButton(Id(:scan_for_networks), _("Scan Network"))
                ),
                VSpacing(0.2),
                ComboBox(
                  Id(:authmode),
                  Opt(:hstretch, :notify),
                  # ComboBox label
                  _("&Authentication Mode"),
                  AuthModeItems(LanItems.wl_auth_modes)
                ),
                VSpacing(0.2),
                @type_w,
                VSpacing(0.2),
                # Text entry label
                Password(Id(:key), _("&Encryption Key"), key),
                VSpacing(0.5)
              ),
              HSpacing(2)
            )
          ),
          VSpacing(0.5),
          HBox(
            # PushButton label
            PushButton(Id(:expert), _("E&xpert Settings")),
            HSpacing(0.5),
            # PushButton label, keys for WEP encryption
            PushButton(Id(:keys), _("&WEP Keys"))
          ),
          VSpacing(0.5)
        ),
        HSpacing(4)
      )
      Wizard.SetContentsButtons(
        caption,
        contents,
        Builtins.sformat(
          "%1%2%3",
          Ops.get_string(@help, "wireless", ""),
          Ops.get_string(@help, "wep_key", ""),
          Ops.get_string(@help, "wpa", "")
        ),
        Label.BackButton,
        Label.NextButton
      )

      #
      # Situation with (E)SSID is not as clear as it should be.
      # According IEEE 802.11-2007 it should be between 0 and 32 octets (sometimes including trailing \0).
      #
      # However, vendors can have additional limits.
      # According http://www.cisco.com/web/techdoc/wireless/access_points/online_help/eag/123-04.JA/1400br/h_ap_sec_ap-client-security.html
      # characters ?, ", $, [, \, ], + are disallowed. Moreover !, #, : shouldn't be at beginning of the id.
      # As this is only part of vendor specification and an APs which breaks that rule (see http://www.wirelessforums.org/alt-internet-wireless/ssid-33892.html)
      # this is ignored.
      #
      # Eventually, as a note to bnc#118157 and bnc#750325 an ' (apostrophe) is valid character in ESSID.
      #
      UI.ChangeWidget(Id(:essid), :ValidChars, String.CPrint)

      UI.ChangeWidget(Id(:authmode), :Value, authmode)
      UI.ChangeWidget(Id(:type_g), :CurrentButton, type) if authmode != "eap"

      ckey = nil
      ret = nil
      loop do
        UI.ChangeWidget(Id(:mode), :Value, "Managed") if authmode_wpa

        UI.ChangeWidget(
          Id(:type_g),
          :Enabled,
          authmode != "no-encryption" && authmode != "eap"
        )
        UI.ChangeWidget(
          Id(:key),
          :Enabled,
          authmode != "no-encryption" && authmode != "eap"
        )
        UI.ChangeWidget(
          Id(:keys),
          :Enabled,
          authmode != "no-encryption" && !authmode_wpa
        )
        UI.ChangeWidget(
          Id("ascii"),
          :Enabled,
          authmode != "no-encryption" && authmode != "psk"
        )

        ret = UI.UserInput

        authmode = Convert.to_string(UI.QueryWidget(Id(:authmode), :Value))
        authmode_wpa = authmode == "psk" || authmode == "eap" # shortcut

        case ret
        when :abort, :cancel
          if ReallyAbort()
            LanItems.Rollback()
            break
          end

          next
        when :back
          break
        when :next, :expert, :keys
          mode = Convert.to_string(UI.QueryWidget(Id(:mode), :Value))
          # WPA-PSK and WPA-EAP are only allowed for Managed mode
          if authmode_wpa && mode != "Managed"
            UI.SetFocus(Id(:mode))
            # Popup text
            Popup.Error(
              _(
                "WPA authentication mode is only possible in managed operating mode."
              )
            )
            next
          end
          essid = Convert.to_string(UI.QueryWidget(Id(:essid), :Value))
          if essid == "" && (mode != "Managed" || authmode_wpa)
            UI.SetFocus(Id(:essid))
            # Popup text
            # modes: combination of operation and authentication
            Popup.Error(_("Specify the network name for this mode."))
            next
          end
          if Ops.greater_than(Builtins.size(essid), 32)
            UI.SetFocus(Id(:essid))
            # Popup text
            Popup.Error(
              _("The network name must be shorter than 32 characters.")
            )
            next
          end

          if authmode != "no-encryption" && authmode != "eap"
            key = Convert.to_string(UI.QueryWidget(Id(:key), :Value))
          else
            key = ""
            Ops.set(LanItems.wl_key, LanItems.wl_default_key, "")
            LanItems.wl_wpa_psk = ""
          end
          type = Convert.to_string(UI.QueryWidget(Id(:type_g), :CurrentButton))
          if authmode == "psk"
            sz = Builtins.size(key)
            if type == "passphrase" &&
                (Ops.less_than(sz, 8) || Ops.greater_than(sz, 63))
              UI.SetFocus(Id(:key))
              # Error popup
              Popup.Error(
                _(
                  "The passphrase must have between 8 and 63 characters (inclusively)."
                )
              )
              next
            elsif type == "hex" &&
                !Builtins.regexpmatch(key, "^[0-9A-Fa-f]{64}$")
              UI.SetFocus(Id(:key))
              # Error popup
              Popup.Error(
                Builtins.sformat(
                  _("The key must have %1 hexadecimal digits."),
                  64
                )
              )
              next
            end
          elsif !authmode_wpa
            ckey = ComposeWepKey(type, key)
            if ckey != ""
              if !CheckWirelessKey(ckey, key_lengths)
                UI.SetFocus(Id(:key))
                # Popup text
                Popup.Error(_("The encryption key is invalid."))
                next
              end
            else
              UI.SetFocus(Id(:key))
              if authmode == "sharedkey" # error
                # Popup text
                Popup.Error(
                  _(
                    "The encryption key must be specified for this authentication mode."
                  )
                )
                next
              elsif ret != :keys # warning only
                # Popup text
                pop = _(
                  "Using no encryption is a security risk.\nReally continue?\n"
                )
                next if !Popup.YesNo(pop)
              end
            end
          end
          break
        when :scan_for_networks
          command = Builtins.sformat(
            "ip link set %1 up && iwlist %1 scan|grep ESSID|cut -d':' -f2|cut -d'\"' -f2|sort -u",
            Ops.get_string(LanItems.Items, [LanItems.current, "ifcfg"], "")
          )
          output = Convert.convert(
            SCR.Execute(path(".target.bash_output"), command),
            from: "any",
            to:   "map <string, any>"
          )

          if Ops.get_integer(output, "exit", -1) == 0
            networks = Builtins.splitstring(
              Ops.get_string(output, "stdout", ""),
              "\n"
            )
            Builtins.y2milestone("Found networks : %1", networks)
            UI.ChangeWidget(:essid, :Items, networks)
          end
        when :authmode
          # do nothing
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next || ret == :expert || ret == :keys
        LanItems.wl_essid = Convert.to_string(
          UI.QueryWidget(Id(:essid), :Value)
        )
        LanItems.wl_mode = mode
        LanItems.wl_auth_mode = authmode
        if authmode == "psk"
          LanItems.wl_wpa_psk = key
          Ops.set(LanItems.wl_key, LanItems.wl_default_key, "")
        elsif !authmode_wpa && authmode != "no-encryption"
          Ops.set(LanItems.wl_key, LanItems.wl_default_key, ckey)
          LanItems.wl_wpa_psk = ""
        end
      end

      if ret == :next && authmode == "eap"
        ret = :eap # continue by the WPA-EAP dialog
      end
      deep_copy(ret)
    end

    # Wireless expert configuration dialog
    # @return dialog result
    def WirelessExpertDialog
      # Wireless expert dialog caption
      caption = _("Wireless Expert Settings")

      # Wireless expert dialog help 1/5
      helptext = _(
        "<p>Here, set additional configuration parameters\n(rarely needed).</p>"
      ) +
        # Wireless expert dialog help 2/5
        _(
          "<p>To use your wireless LAN card in master or ad-hoc mode,\n" \
            "set the <b>Channel</b> the card should use here. This is not needed\n" \
            "for managed mode--the card will hop through the channels searching for access\n" \
            "points in that case.</p>\n"
        ) +
        # Wireless expert dialog help 3/5
        _(
          "<p>In some rare cases, you may want to set a transmission\n<b>Bit Rate</b> explicitly. The default is to go as fast as possible.</p>"
        ) +
        # Wireless expert dialog help 4/5
        _(
          "<p>In an environment with multiple <b>Access Points</b>, you may want to\ndefine the one to which to connect by entering its MAC address.</p>"
        ) +
        # Wireless expert dialog help 5/5
        _(
          "<p><b>Use Power Management</b> enables power saving mechanisms.\n" \
            "This is generally a good idea, especially if you are a laptop user and may\n" \
            "be disconnected from AC power.</p>\n"
        )

      channels = [
        "1",
        "2",
        "3",
        "4",
        "5",
        "6",
        "7",
        "8",
        "9",
        "10",
        "11",
        "12",
        "13",
        "14"
      ]
      channels = deep_copy(LanItems.wl_channels) if !LanItems.wl_channels.nil?
      if LanItems.wl_channel != "" &&
          !Builtins.contains(channels, LanItems.wl_channel)
        channels = Builtins.prepend(channels, LanItems.wl_channel)
      end
      # Combobox item
      channels = Builtins.prepend(channels, Item(Id(""), _("Automatic")))

      bitrates = [
        "54",
        "48",
        "36",
        "24",
        "18",
        "12",
        "11",
        "9",
        "6",
        "5.5",
        "2",
        "1"
      ]
      bitrates = deep_copy(LanItems.wl_bitrates) if !LanItems.wl_bitrates.nil?
      if LanItems.wl_bitrate != "" &&
          !Builtins.contains(bitrates, LanItems.wl_bitrate)
        bitrates = Builtins.prepend(bitrates, LanItems.wl_bitrate)
      end
      # Combobox item
      bitrates = Builtins.prepend(bitrates, Item(Id(""), _("Automatic")))

      # Wireless expert dialog contents
      contents = HBox(
        HSpacing(4),
        VBox(
          VSpacing(0.5),
          # Frame label
          Frame(
            _("Wireless Expert Settings"),
            HBox(
              HSpacing(2),
              VBox(
                VSpacing(1),
                # Combobox label
                ComboBox(Id(:channel), Opt(:hstretch), _("&Channel"), channels),
                VSpacing(0.2),
                # Combobox label
                ComboBox(Id(:bitrate), Opt(:hstretch), _("B&it Rate"), bitrates),
                VSpacing(0.2),
                # Text entry label
                InputField(
                  Id(:accesspoint),
                  Opt(:hstretch),
                  _("&Access Point"),
                  LanItems.wl_accesspoint
                ),
                VSpacing(0.2),
                # CheckBox label
                Left(
                  CheckBox(
                    Id(:power),
                    _("Use &Power Management"),
                    LanItems.wl_power == true
                  )
                ),
                VSpacing(0.2),
                Left(
                  IntField(
                    Id(:ap_scanmode),
                    Opt(:hstretch),
                    _("AP ScanMode"),
                    0,
                    2,
                    Builtins.tointeger(LanItems.wl_ap_scanmode)
                  )
                ),
                VSpacing(1)
              ),
              HSpacing(2)
            )
          ),
          VSpacing(0.5)
        ),
        HSpacing(4)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      UI.ChangeWidget(Id(:bitrate), :Value, LanItems.wl_bitrate)
      UI.ChangeWidget(Id(:channel), :Value, LanItems.wl_channel)
      # #88530
      channel_changeable = Builtins.contains(
        ["Ad-hoc", "Master"],
        LanItems.wl_mode
      )
      UI.ChangeWidget(Id(:channel), :Enabled, channel_changeable)

      ret = nil
      loop do
        ret = UI.UserInput

        case ret
        when :abort, :cancel
          if ReallyAbort()
            LanItems.Rollback()
            break
          end

          next
        when :back
          break
        when :next
          # Check
          break
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next
        LanItems.wl_channel = Convert.to_string(
          UI.QueryWidget(Id(:channel), :Value)
        )
        #	LanItems::wl_frequency = (string) UI::QueryWidget(`id(`frequency), `Value);
        LanItems.wl_bitrate = Convert.to_string(
          UI.QueryWidget(Id(:bitrate), :Value)
        )
        LanItems.wl_accesspoint = Convert.to_string(
          UI.QueryWidget(Id(:accesspoint), :Value)
        )
        LanItems.wl_power = Convert.to_boolean(
          UI.QueryWidget(Id(:power), :Value)
        ) == true
        LanItems.wl_ap_scanmode = Builtins.tostring(
          UI.QueryWidget(Id(:ap_scanmode), :Value)
        )
      end

      deep_copy(ret)
    end

    # Used to add or edit a key
    # @param [String] tkey has s: for ascii or h: for passphrase
    # @param [Array<Fixnum>] lengths allowed real key lengths
    def WirelessKeyPopup(tkey, lengths)
      lengths = deep_copy(lengths)
      wkey = ParseWepKey(tkey)
      key = Ops.get(wkey, "key", "")
      type = Ops.get(wkey, "type", "")

      contents = HBox(
        HSpacing(1),
        VBox(
          VSpacing(0.2),
          # Translators: popup dialog heading
          Heading(_("Enter Encryption Key")),
          @type_w, # common with the main dialog
          VSpacing(0.5),
          # Translators: text entry label
          Left(TextEntry(Id(:key), _("&Key"), key)),
          VSpacing(0.2),
          HBox(
            PushButton(Id(:ok), Opt(:default, :key_F10), Label.OKButton),
            PushButton(Id(:cancel), Opt(:key_F9), Label.CancelButton),
            PushButton(Id(:help), Opt(:key_F1), Label.HelpButton)
          ),
          VSpacing(0.2)
        ),
        HSpacing(1)
      )

      UI.OpenDialog(Opt(:decorated), contents)
      UI.ChangeWidget(Id(:type_g), :CurrentButton, type)
      UI.SetFocus(Id(:key))

      ret = nil
      ckey = nil
      loop do
        ret = UI.UserInput

        if ret == :help
          # Translators: popup title
          Popup.LongText(
            _("Help"),
            RichText(Ops.get_string(@help, "wep_key", "")),
            50,
            18
          )
        elsif ret == :cancel
          break
        elsif ret == :ok
          key = Convert.to_string(UI.QueryWidget(Id(:key), :Value))
          type = Convert.to_string(UI.QueryWidget(Id(:type_g), :CurrentButton))
          ckey = ComposeWepKey(type, key)
          break if CheckWirelessKey(ckey, lengths)
          UI.SetFocus(Id(:key))
          # Popup text
          Popup.Error(_("The encryption key is invalid."))
        else
          Builtins.y2error("Unexpected return code: %1", ret)
        end
      end

      tkey = ckey if ret == :ok

      UI.CloseDialog

      tkey
    end

    # Generate items for the keys table
    def WirelessKeysItems(keys, defaultk)
      keys = deep_copy(keys)
      Builtins.maplist([0, 1, 2, 3]) do |i|
        Item(Id(i), i, Ops.get(keys, i, ""), i == defaultk ? "*" : "")
      end
    end

    # In case the current default key is empty, find a nonempty one
    # or the first one.
    def FindGoodDefault(keys, defaultk)
      keys = deep_copy(keys)
      return defaultk if Ops.get(keys, defaultk, "") != ""
      defaultk = Builtins.find([0, 1, 2, 3]) { |i| Ops.get(keys, i, "") != "" }
      defaultk = 0 if defaultk.nil?
      defaultk
    end

    # Wireless expert configuration dialog
    # @return dialog result
    def WirelessKeysDialog
      # Wireless keys dialog caption
      caption = _("Wireless Keys")

      # Wireless keys dialog help 1/3
      helptext = _(
        "<p>In this dialog, define your WEP keys used\n" \
          "to encrypt your data before it is transmitted. You can have up to four keys,\n" \
          "although only one key is used to encrypt the data. This is the default key.\n" \
          "The other keys can be used to decrypt data. Usually you have only\n" \
          "one key.</p>"
      ) +
        # Wireless keys dialog help 2/3
        _(
          "<p><b>Key Length</b> defines the bit length of your WEP keys.\n" \
            "Possible are 64 and 128 bit, sometimes also referred to as 40 and 104 bit.\n" \
            "Some older hardware might not be able to handle 128 bit keys, so if your\n" \
            "wireless LAN connection does not establish, you may need to set this\n" \
            "value to 64.</p>"
        ) + ""

      length = LanItems.wl_key_length
      ui_key_lengths = Builtins.maplist(ParseKeyLengths(LanItems.wl_enc_modes)) do |kl|
        Builtins.tostring(Ops.add(kl, 24))
      end
      if !Builtins.contains(ui_key_lengths, length)
        ui_key_lengths = Builtins.add(ui_key_lengths, length)
      end
      keys = deep_copy(LanItems.wl_key)
      defaultk = FindGoodDefault(keys, LanItems.wl_default_key)

      # Wireless keys dialog contents
      contents = HBox(
        HSpacing(5),
        VBox(
          VSpacing(1),
          # Frame label
          Frame(
            _("WEP Keys"),
            HBox(
              HSpacing(3),
              VBox(
                VSpacing(1),
                # ComboBox label
                Left(ComboBox(Id(:length), _("&Key Length"), ui_key_lengths)),
                VSpacing(1),
                Table(
                  Id(:table),
                  Opt(:notify),
                  Header(
                    # Table header label
                    # Abbreviation of Number
                    _("No."),
                    # Table header label
                    _("Key"),
                    # Table header label
                    Center(_("Default"))
                  ),
                  WirelessKeysItems(keys, defaultk)
                ),
                HBox(
                  # PushButton label
                  PushButton(Id(:edit), Label.EditButton),
                  # PushButton label
                  PushButton(Id(:delete), Label.DeleteButton),
                  # PushButton label
                  PushButton(Id(:default), _("&Set as Default"))
                ),
                VSpacing(1)
              ),
              HSpacing(3)
            )
          ),
          VSpacing(1)
        ),
        HSpacing(5)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      UI.ChangeWidget(Id(:length), :Value, length)

      current = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))

      ret = nil
      loop do
        Builtins.foreach([:edit, :delete, :default]) do |btn|
          UI.ChangeWidget(Id(btn), :Enabled, !current.nil?)
        end

        UI.SetFocus(Id(:table))
        ret = UI.UserInput

        current = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
        length = Convert.to_string(UI.QueryWidget(Id(:length), :Value))
        rlength = Ops.subtract(Builtins.tointeger(length), 24)

        case ret
        when :abort, :cancel
          if ReallyAbort()
            LanItems.Rollback()
            break
          end

          next
        when :table, :edit, :delete
          Ops.set(
            keys,
            current,
            if ret != :delete
              WirelessKeyPopup(Ops.get(keys, current, ""), [rlength])
            else
              ""
            end
          )
          defaultk = FindGoodDefault(keys, defaultk)
          UI.ChangeWidget(Id(:table), :Items, WirelessKeysItems(keys, defaultk))
        when :default
          defaultk = FindGoodDefault(keys, current)
          UI.ChangeWidget(Id(:table), :Items, WirelessKeysItems(keys, defaultk))
        when :next, :back
          break
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next
        LanItems.wl_key_length = length
        LanItems.wl_key = deep_copy(keys)
        LanItems.wl_default_key = defaultk
      end

      deep_copy(ret)
    end

    # -------------------- WPA EAP --------------------

    # function to initialize widgets
    # @param [String] key widget id
    def InitializeWidget(key)
      # the "" serves instead of a default constructor for wl_wpa_eap
      value = Ops.get_string(LanItems.wl_wpa_eap, key, "")
      my2debug("AW", Builtins.sformat("init k: %1, v: %2", key, value))
      UI.ChangeWidget(Id(key), ValueProp(key), value)

      nil
    end

    # function to store data from widget
    # @param [String] key widget id
    # @param [Hash] event ?
    def StoreWidget(key, event)
      event = deep_copy(event)
      value = UI.QueryWidget(Id(key), ValueProp(key))
      my2debug(
        "AW",
        Builtins.sformat("store k: %1, v: %2, e: %3", key, value, event)
      )
      Ops.set(LanItems.wl_wpa_eap, key, value)

      nil
    end

    # Event handler for EAP mode:
    # enable or disable appropriate widgets
    # @param key [String] the widget receiving the event
    # @param _event [Hash] the event being handled
    # @return nil so that the dialog loops on
    def HandleEapMode(key, _event)
      tls = UI.QueryWidget(Id(key), :Value) == "TLS"
      Builtins.foreach(["WPA_EAP_PASSWORD", "WPA_EAP_ANONID", "DETAILS_B"]) do |id|
        UI.ChangeWidget(Id(id), :Enabled, !tls)
      end
      Builtins.foreach(
        [
          "WPA_EAP_CLIENT_CERT",
          "WPA_EAP_CLIENT_CERT_BROWSE",
          "WPA_EAP_CLIENT_KEY",
          "WPA_EAP_CLIENT_KEY_BROWSE",
          "WPA_EAP_CLIENT_KEY_PASSWORD"
        ]
      ) { |id| UI.ChangeWidget(Id(id), :Enabled, tls) }
      nil
    end

    # function to initialize widgets
    # @param [String] key widget id
    def InitEapMode(key)
      # inherited
      InitializeWidget(key)
      # enable/disable
      HandleEapMode(key, "ID" => "_cwm_wakeup")

      nil
    end

    # function to initialize widgets
    # @param [String] key widget id
    def InitPeapVersion(key)
      # inherited
      InitializeWidget(key)
      # enable/disable
      mode = Ops.get_string(LanItems.wl_wpa_eap, "WPA_EAP_MODE", "")
      UI.ChangeWidget(Id(key), :Enabled, mode == "peap")

      nil
    end

    # Called when one of the two file browser buttons is pressed
    # @param [String] key widget id
    # @param [Hash] event ?
    # @return nil so that the dialog does not exit
    def HandleFileBrowse(key, event)
      event = deep_copy(event)
      # only process our own events
      return nil if Ops.get(event, "ID") != key

      # convert to the text entry widget we belong to
      attached_to = {
        "WPA_EAP_CLIENT_CERT_BROWSE" => "WPA_EAP_CLIENT_CERT",
        "WPA_EAP_CLIENT_KEY_BROWSE"  => "WPA_EAP_CLIENT_KEY",
        "WPA_EAP_CA_CERT_BROWSE"     => "WPA_EAP_CA_CERT"
      }
      key = Ops.get_string(attached_to, key, "")

      # get the file and its directory if already entered
      file = Convert.to_string(UI.QueryWidget(Id(key), :Value))
      slashpos = Builtins.findlastof(file, "/")
      defaultd = "." # "/etc/cert";
      dir = slashpos.nil? ? defaultd : Builtins.substring(file, 0, slashpos)

      # file browser dialog headline
      file = UI.AskForExistingFile(dir, "*", _("Choose a Certificate"))

      if !file.nil?
        # fill the value
        UI.ChangeWidget(Id(key), :Value, file)
      end
      nil
    end

    # Remap the buttons to their Wizard Sequencer values
    # @param _key [String] the widget receiving the event
    # @param event [Hash] the event being handled
    # @return nil so that the dialog loops on
    def HandleDetails(_key, event)
      event = deep_copy(event)
      return :details if Ops.get(event, "ID") == "DETAILS_B"
      nil
    end

    # Called to validate that the file entered exists
    # @param key [String] widget id
    # @param _event [Hash] the event being handled
    # @return ok?
    def ValidateFileExists(key, _event)
      file = Convert.to_string(UI.QueryWidget(Id(key), :Value))

      if file == ""
        return true # validated in ValidateWpaEap
      end

      return true if FileUtils.Exists(file)

      UI.SetFocus(Id(key))
      Popup.Error(Message.CannotOpenFile(file))
      false
    end

    def ValidateCaCertExists(key, event)
      event = deep_copy(event)
      ret = true
      if Builtins.size(Convert.to_string(UI.QueryWidget(Id(key), :Value))) == 0 ||
          !ValidateFileExists(key, event)
        if !Popup.YesNo(
          _(
            "Not using a Certificate Authority (CA) certificate can result in connections\nto insecure, rogue wireless networks. Continue without CA ?"
          )
        )
          ret = false
        end
      end
      ret
    end

    # Called to validate that the whole dialog makes sense together
    # @param _key [String] widget id
    # @param _event [Hash] the event being handled
    # @return ok?
    def ValidateWpaEap(_key, _event)
      tmp = Builtins.listmap(
        [
          "WPA_EAP_IDENTITY",
          # "WPA_EAP_PASSWORD",
          "WPA_EAP_CLIENT_CERT"
        ]
      ) { |key2| { key2 => UI.QueryWidget(Id(key2), :Value) } }

      if Ops.get_string(tmp, "WPA_EAP_CLIENT_CERT", "") == "" &&
          Ops.get_string(tmp, "WPA_EAP_IDENTITY", "") == ""
        UI.SetFocus(Id("WPA_EAP_IDENTITY"))
        # error popup text
        Popup.Error(
          _(
            "Enter either the identity and password\nor the client certificate."
          )
        )
        return false
      else
        return true
      end
    end

    # Lays out a text entry and a push button, with proper alignment
    def AddButton(id, button_id)
      #    return `HBox (id, button_id);
      # needs new CWM
      VSquash(HBox(id, Bottom(button_id))) # only for old UI?
    end

    # Settings for WPA-EAP
    # @return dialog result
    def WirelessWpaEapDialog
      contents = VBox(
        "WPA_EAP_MODE",
        "WPA_EAP_DUMMY",
        HBox("WPA_EAP_IDENTITY", HSpacing(1), "WPA_EAP_PASSWORD"),
        "WPA_EAP_ANONID",
        AddButton("WPA_EAP_CLIENT_CERT", "WPA_EAP_CLIENT_CERT_BROWSE"),
        HBox(
          AddButton("WPA_EAP_CLIENT_KEY", "WPA_EAP_CLIENT_KEY_BROWSE"),
          HSpacing(1),
          "WPA_EAP_CLIENT_KEY_PASSWORD"
        ),
        AddButton("WPA_EAP_CA_CERT", "WPA_EAP_CA_CERT_BROWSE"),
        VSpacing(1),
        Right("DETAILS_B")
      )

      functions = {
        "init"  => fun_ref(method(:InitializeWidget), "void (string)"),
        "store" => fun_ref(method(:StoreWidget), "void (string, map)"),
        :abort  => fun_ref(method(:ReallyAbort), "boolean ()")
      } # undocumented, FIXME

      CWM.ShowAndRun(
        "widget_descr"       => @wpa_eap_widget_descr,
        "contents"           => contents,
        # dialog caption
        "caption"            => _("WPA-EAP"),
        "back_button"        => Label.BackButton,
        "next_button"        => Label.NextButton,
        "fallback_functions" => functions
      )
    end

    # Detailed settings for WPA-EAP
    # @return dialog result
    def WirelessWpaEapDetailsDialog
      contents = HSquash(
        VBox("WPA_EAP_AUTH", VSpacing(1), "WPA_EAP_PEAP_VERSION")
      )

      functions = {
        "init"  => fun_ref(method(:InitializeWidget), "void (string)"),
        "store" => fun_ref(method(:StoreWidget), "void (string, map)"),
        :abort  => fun_ref(method(:ReallyAbort), "boolean ()")
      }

      auth_names = {
        # combo box item, any of EAP authentication methods
        ""         => _(
          "Any"
        ),
        # combo box item, an EAP authentication method
        "MD5"      => _("MD5"),
        # combo box item, an EAP authentication method
        "GTC"      => _("GTC"),
        # combo box item, an EAP authentication method
        "CHAP"     => _("CHAP"),
        # combo box item, an EAP authentication method
        "PAP"      => _("PAP"),
        # combo box item, an EAP authentication method
        "MSCHAP"   => _(
          "MSCHAPv1"
        ),
        # combo box item, an EAP authentication method
        "MSCHAPV2" => _(
          "MSCHAPv2"
        )
      }
      auth_items = {
        "TTLS" => ["", "MD5", "GTC", "CHAP", "PAP", "MSCHAP", "MSCHAPV2"],
        "PEAP" => ["", "MD5", "GTC", "MSCHAPV2"]
      }
      mode = Ops.get_string(LanItems.wl_wpa_eap, "WPA_EAP_MODE", "")

      wd = deep_copy(@wpa_eap_widget_descr)
      Ops.set(
        wd,
        ["WPA_EAP_AUTH", "items"],
        Builtins.maplist(Ops.get(auth_items, mode, [])) do |i|
          [i, Ops.get(auth_names, i, "")]
        end
      )

      CWM.ShowAndRun(
        "widget_descr"       => wd,
        "contents"           => contents,
        # dialog caption
        "caption"            => _("WPA-EAP Details"),
        "back_button"        => Label.BackButton,
        "next_button"        => Label.OKButton,
        "fallback_functions" => functions
      )
    end
  end
end
