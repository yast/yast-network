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
# File:	include/network/provider/provider.ycp
# Package:	Network configuration
# Summary:	Provider dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkProviderProviderInclude
    def initialize_network_provider_provider(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "ISDN"
      Yast.import "Provider"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/provider/helps.rb"
      Yast.include include_target, "network/provider/texts.rb"

      Yast.import "Popup"
      Yast.import "Label"
    end

    # Build provider info text.
    # @return provider info text
    def ProviderInfoText
      info = ""
      type = Provider.Type

      hp = Ops.get_string(Provider.Current, "HOMEPAGE", "")
      hl = Ops.get_string(Provider.Current, "HOTLINE", "")

      if hp != ""
        # Provider info (%1 is URL)
        info = Ops.add(info, Builtins.sformat(_("<p>Home Page: %1</p>"), hp))
      end

      if hl != ""
        # Provider info (%1 is phone number)
        info = Ops.add(info, Builtins.sformat(_("<p>Hot Line: %1</p>"), hl))
      end


      if Ops.get_string(Provider.Current, "DIALMESSAGE1", "") != "" ||
          Ops.get_string(Provider.Current, "DIALMESSAGE2", "") != ""
        info = Ops.add(
          info,
          Builtins.sformat(
            "<p>%1%2</p>",
            Ops.get_string(Provider.Current, "DIALMESSAGE1", ""),
            Ops.get_string(Provider.Current, "DIALMESSAGE2", "")
          )
        )
      elsif Ops.get_string(Provider.Current, "PHONE", "") == "" && type != "dsl"
        if hp != "" && hl != ""
          # Provider info text
          it = _(
            "<p>To register for <b>%1</b> and find the best\n" +
              "dialing number, connect to the home page <b>%2</b> or call the hot line\n" +
              "<b>%3</b>.</p>\n"
          )

          info = Ops.add(
            info,
            Builtins.sformat(
              it,
              Ops.get_string(Provider.Current, "PROVIDER", ""),
              hp,
              hl
            )
          )
        end

        if hp != "" && hl == ""
          # Provider info text
          it = _(
            "<p>To register for <b>%1</b> and find the best\ndialing number, connect to the home page <b>%2</b>.</p>"
          )

          info = Ops.add(
            info,
            Builtins.sformat(
              it,
              Ops.get_string(Provider.Current, "PROVIDER", ""),
              hp
            )
          )
        end

        if hp == "" && hl != ""
          # Provider info text
          it = _(
            "<p>To register for <b>%1</b> and find the best\ndialing number, call the hot line <b>%2</b>.</p>\n"
          )

          info = Ops.add(
            info,
            Builtins.sformat(
              it,
              Ops.get_string(Provider.Current, "PROVIDER", ""),
              hl
            )
          )
        end
      end

      info
    end

    # Provider dialog
    # @return dialog result
    def ProviderDialog
      type = Provider.Type

      name = Ops.get_string(Provider.Current, "PROVIDER", "")
      phone = Ops.get_string(Provider.Current, "PHONE", "")
      encap = Ops.get_string(Provider.Current, "ENCAP", "")
      infotext = ProviderInfoText()

      username = Ops.get_string(Provider.Current, "USERNAME", "")
      password = Ops.get_string(Provider.Current, "PASSWORD", "")
      ask_pass = Ops.get_string(Provider.Current, "ASKPASSWORD", "no") == "yes"
      # #59836: T-Online forbids the users to store unencrypted passwords,
      # so let's not encourage it.
      # We don't simply change the default for ASKPASSWORD to yes because
      # that would ruin the universal accounts like Raz:Dva
      ask_pass = true if username == "" && password == ""

      uimode = Ops.get_string(Provider.Current, "UIMODE", "")

      lineid = ""
      t_onlineid = ""
      usercode = ""

      # Create T-Online username from LineID, T-OnlineNo and UserCode
      #
      # It's concatenation of LineID (12 digits), T-OnlineNo (12 digits,
      # if less, then with appended '#', the user code (4 digits) and
      # finally of the string "@t-online.de" if the type is "dsl".
      #
      # T-Online Business DSL is created as
      # t-online-com/<12 character (real) username>@t-online-com.de
      tonline2username = lambda do
        if uimode == "T-Online DSL Business"
          username = Ops.add(
            Ops.add("t-online-com/", username),
            "@t-online-com.de"
          )
        else
          username = Ops.add(
            Ops.add(
              Ops.add(
                Ops.add(lineid, t_onlineid),
                Ops.less_than(Builtins.size(t_onlineid), 12) ? "#" : ""
              ),
              usercode
            ),
            uimode == "T-Online DSL" ? "@t-online.de" : ""
          )
        end

        Builtins.y2debug(
          "T-Online: [%1,%2,%3] -> %4",
          lineid,
          t_onlineid,
          usercode,
          username
        )

        nil
      end

      # Split username to LineID, T-OnlineNo and UserCode
      # @see #tonline2username
      username2tonline = lambda do
        user = username
        usercode = "0001"
        lineid = ""
        t_onlineid = ""

        Builtins.y2debug("user=%1", user)
        if user != ""
          if uimode == "T-Online DSL Business"
            if Builtins.regexpmatch(user, "@t-online-com.de$")
              user = Builtins.regexpsub(user, "^(.*)@t-online-com.de$", "\\1")
            end
            Builtins.y2debug("user=%1", user)

            if Builtins.regexpmatch(user, "^t-online-com/")
              user = Builtins.regexpsub(user, "^t-online-com/(.*)$", "\\1")
            end
            Builtins.y2debug("user=%1", user)
            username = user
          else
            if Builtins.regexpmatch(user, "@t-online.de$")
              user = Builtins.regexpsub(user, "^(.*)@t-online.de$", "\\1")
            end
            Builtins.y2debug("user=%1", user)

            if Builtins.issubstring(user, "#")
              usercode = Builtins.regexpsub(user, "^.*#(.*)$", "\\1")
              user = Builtins.regexpsub(user, "^(.*)#.*$", "\\1")
            else
              if Ops.greater_than(Builtins.size(user), 3)
                usercode = Builtins.regexpsub(user, "^.*(....)$", "\\1")
                user = Builtins.regexpsub(user, "^(.*)....$", "\\1")
              end
            end
            usercode = "0001" if usercode == ""

            Builtins.y2debug("user=%1", user)
            if Ops.greater_than(Builtins.size(user), 12)
              lineid = Builtins.regexpsub(user, "^(.{12}).*$", "\\1")
              t_onlineid = Builtins.regexpsub(user, "^.{12}(.*)$", "\\1")
            else
              lineid = user
            end
          end
        end
        Builtins.y2debug(
          "T-Online: %1 -> [%2,%3,%4]",
          username,
          lineid,
          t_onlineid,
          usercode
        )

        nil
      end

      username2tonline.call if Builtins.issubstring(uimode, "T-Online")

      # Provider dialog caption
      caption = _("Provider Parameters")

      # Provider dialog help 1/5
      helptext = _(
        "<p>Configure access to your Internet provider. If you have\nselected your provider from the  list, these values are provided.</p>\n"
      ) +
        (type == "dsl" ?
          # Provider dialog help 1.5/5: DSL, thus no phone number
          _("<p>Enter a <b>Provider Name</b> for the provider.</p>") :
          # Provider dialog help 1.5/5
          _(
            "<p>Enter a <b>Provider Name</b> for the provider and a <b>Phone Number</b>\nto access your provider.</p>"
          ))

      if type == "isdn" # FIXME: ISDN ???
        # Provider dialog help 2/5
        helptext = Ops.add(
          helptext,
          _(
            "<p>Select the type of packet encapsulation.\n" +
              "<b>RawIP</b> means that MAC headers are stripped. <b>SyncPPP</b> stands for\n" +
              "Synchronous PPP.</p>"
          )
        )
      end

      if uimode == "T-Online" || uimode == "T-Online DSL"
        # Provider dialog help 4/5 (T-Online)
        helptext = Ops.add(
          helptext,
          _(
            "<p>Enter the <b>Line ID</b>\n" +
              "(e.g., 00056780362), the <b>T-Online Number</b> (e.g., 870008594732),\n" +
              "the <b>User Code</b> (typically 0001), and the <b>Password</b>\n" +
              "to use as the login (ask your provider if unsure).</p>"
          )
        )
      else
        # Provider dialog help 4/5 (general)
        helptext = Ops.add(
          helptext,
          _(
            "<p>Enter the <b>User Name</b> and the\n<b>Password</b> to use as the login (ask your provider if unsure).</p>"
          )
        )
      end

      if uimode == "T-Online DSL Business"
        # Provider dialog help 4.5/5 (T-Online Business)
        helptext = Ops.add(
          helptext,
          _(
            "<p>The <b>User Name</b> will be extended\n" +
              "with the <i>t-online-com/</i> at the start and with <i>@t-online-com.de</i>\n" +
              "at the end.</p>"
          )
        )
      end

      # #59836
      # Provider dialog help 5/5
      helptext = Ops.add(
        helptext,
        _(
          "<p>Check <b>Always Ask for Password</b> to be asked for the password every time.\n" +
            "Your\n" +
            "Internet service provider might not allow passwords to be saved on\n" +
            "disk. If you enter the password here, it is saved in clear text on disk\n" +
            "(readable by root only).\n" +
            "</p>\n"
        )
      )


      # Frame label
      auth = Frame(
        Id(:auth),
        _("Authorization"),
        HBox(
          HSpacing(0.5),
          VBox(
            # TextEntry label
            TextEntry(Id(:username), _("&User Name"), username),
            Label(""),
            VSpacing(0.2)
          ),
          HSpacing(0.5),
          VBox(
            Password(Id(:password), Label.Password, password),
            # CheckBox label
            Left(
              CheckBox(
                Id(:askpass),
                Opt(:notify),
                _("&Always Ask for Password"),
                ask_pass
              )
            ),
            VSpacing(0.2)
          ),
          HSpacing(0.5)
        )
      )

      encapbox = Empty()
      if type == "isdn"
        # ComboBox label
        encapbox = Left(
          ComboBox(
            Id(:encap),
            Opt(:notify),
            _("Packet &Encapsulation"),
            [
              # ComboBox item
              Item(Id("syncppp"), _("Synchronous PPP"), encap == "syncppp"),
              # ComboBox item
              Item(Id("rawip"), _("Raw IP"), encap == "rawip")
            ]
          )
        ) 
        # if (encap == "" && ISDN::operation == `addif)
        # 	encap = ISDN::interface["PROTOCOL"]:"syncppp";
      end

      # TextEntry label
      namebox = TextEntry(Id(:name), _("Pr&ovider Name"), name)

      # TextEntry label
      phonebox = TextEntry(Id(:phone), _("P&hone Number"), phone)

      if type == "dsl"
        phonebox = deep_copy(namebox)
        namebox = VSpacing(0)
      end

      phonebox = HBox(
        phonebox,
        HSpacing(0.5),
        VBox(
          Label(""),
          # PushButton label
          PushButton(Id(:info), Opt(:disabled), _("&Info"))
        )
      )

      # Provider specific UI mode
      # if(issubstring(uimode, "T-Online"))
      if uimode == "T-Online" || uimode == "T-Online DSL"
        Builtins.y2debug("Using uimode=%1", uimode)

        auth = Frame(
          Id(:auth),
          _("Authorization"),
          VBox(
            HBox(
              HSpacing(0.5),
              # TextEntry label
              TextEntry(Id(:lineid), _("&Line ID"), lineid),
              HSpacing(0.5),
              # TextEntry label
              TextEntry(Id(:t_onlineid), _("&T-Online Number"), t_onlineid),
              HSpacing(0.5)
            ),
            VSpacing(0.5),
            HBox(
              HSpacing(0.5),
              VBox(
                # TextEntry label
                TextEntry(Id(:usercode), _("&User Code"), usercode),
                Label(""),
                VSpacing(0.2)
              ),
              HSpacing(0.5),
              VBox(
                Password(Id(:password), Label.Password, password),
                # CheckBox label
                Left(
                  CheckBox(
                    Id(:askpass),
                    Opt(:notify),
                    _("&Always Ask for Password"),
                    ask_pass
                  )
                ),
                VSpacing(0.2)
              ),
              HSpacing(0.5)
            )
          )
        )
      end

      # Provider dialog contents
      contents = VBox(
        VSpacing(2),
        HBox(
          HSpacing(4),
          VBox(
            Left(
              HBox(
                # Label text
                Label(_("Name for Dialing:")),
                HSpacing(0.5),
                Label(Opt(:outputField), Provider.Name)
              )
            ), #`VSpacing(0.5),
            #ip
            VSpacing(1),
            namebox,
            VSpacing(0.5),
            phonebox,
            VSpacing(0.5),
            encapbox,
            type == "isdn" ? VSpacing(1) : Empty(),
            auth
          ),
          HSpacing(4)
        ),
        VSpacing(2)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.NextButton
      )

      # '*' and '#' are for GPRS connections (#16021)
      # ',' is for pausing dialing (#23678)
      # `phone: in rare cases other characters are allowed (#43723)
      phonevalidchars = "0123456789*#,"
      ChangeWidgetIfExists(Id(:usercode), :ValidChars, "0123456789#")
      ChangeWidgetIfExists(Id(:lineid), :ValidChars, "0123456789")
      ChangeWidgetIfExists(Id(:t_onlineid), :ValidChars, "0123456789")

      ChangeWidgetIfExists(Id(:password), :Enabled, !ask_pass)
      ChangeWidgetIfExists(
        Id(:info),
        :Enabled,
        infotext != nil && infotext != ""
      )

      if type == "isdn" && encap == "rawip"
        # seems that disabling via frame is not possible
        # UI::ChangeWidget(`id(`auth), `Enabled, false);
        ChangeWidgetIfExists(Id(:username), :Enabled, false)
        ChangeWidgetIfExists(Id(:usercode), :Enabled, false)
        ChangeWidgetIfExists(Id(:lineid), :Enabled, false)
        ChangeWidgetIfExists(Id(:t_onlineid), :Enabled, false)
        UI.ChangeWidget(Id(:password), :Enabled, false)
        UI.ChangeWidget(Id(:askpass), :Enabled, false)
      end

      # MAIN CYCLE
      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          if ReallyAbort()
            break
          else
            next
          end
        # back
        elsif ret == :back
          break
        elsif ret == :encap
          encap = Convert.to_string(UI.QueryWidget(Id(:encap), :Value))
          e = encap == "syncppp"
          # seems that disabling via frame is not possible
          # UI::ChangeWidget(`id(`auth), `Enabled, encap == "syncppp");
          ChangeWidgetIfExists(Id(:username), :Enabled, e)
          ChangeWidgetIfExists(Id(:usercode), :Enabled, e)
          ChangeWidgetIfExists(Id(:lineid), :Enabled, e)
          ChangeWidgetIfExists(Id(:t_onlineid), :Enabled, e)
          UI.ChangeWidget(
            Id(:password),
            :Enabled,
            e && !Convert.to_boolean(UI.QueryWidget(Id(:askpass), :Value))
          )
          UI.ChangeWidget(Id(:askpass), :Enabled, e)
          next
        elsif ret == :info
          # Popup text header
          Popup.LongText(_("Provider Information"), RichText(infotext), 43, 13)
          next
        elsif ret == :askpass
          UI.ChangeWidget(
            Id(:password),
            :Enabled,
            !Convert.to_boolean(UI.QueryWidget(Id(:askpass), :Value))
          )
          next
        # next
        elsif ret == :next
          # check_*
          name = Convert.to_string(UI.QueryWidget(Id(:name), :Value))
          username = Convert.to_string(
            QueryWidgetIfExists(Id(:username), :Value, username)
          )
          password = Convert.to_string(UI.QueryWidget(Id(:password), :Value))
          ask_pass = Convert.to_boolean(UI.QueryWidget(Id(:askpass), :Value))

          phone = Convert.to_string(
            QueryWidgetIfExists(Id(:phone), :Value, phone)
          )

          auth_chk = true
          if type == "isdn"
            encap = Convert.to_string(UI.QueryWidget(Id(:encap), :Value))
            auth_chk = false if encap == "rawip"
          end

          # if(issubstring(uimode, "T-Online"))
          if uimode == "T-Online" || uimode == "T-Online DSL"
            lineid = Convert.to_string(UI.QueryWidget(Id(:lineid), :Value))
            t_onlineid = Convert.to_string(
              UI.QueryWidget(Id(:t_onlineid), :Value)
            )
            usercode = Convert.to_string(UI.QueryWidget(Id(:usercode), :Value))

            if lineid == ""
              # Popup::Message text
              Popup.Message(_("Enter the line ID."))
              UI.SetFocus(Id(:lineid))
              next
            end
            if t_onlineid == ""
              # Popup::Message text
              Popup.Message(_("Enter the T-Online number."))
              UI.SetFocus(Id(:t_onlineid))
              next
            end
            if usercode == ""
              # Popup::Message text
              Popup.Message(_("Enter the user code."))
              UI.SetFocus(Id(:usercode))
              next
            end

            tonline2username.call
          elsif uimode == "T-Online DSL Business"
            tonline2username.call
          end

          if name != Ops.get_string(Provider.Current, "PROVIDER", "") &&
              !Provider.IsUnique(name)
            Builtins.y2debug(
              "n(%1), p(%2)",
              name,
              Ops.get_string(Provider.Current, "PROVIDER", "")
            )
            # Popup::Message text
            Popup.Message(
              Builtins.sformat(_("Provider name %1 already exists."), name)
            )
            UI.SetFocus(Id(:name))
            next
          elsif name == ""
            # Popup::Message text
            Popup.Message(_("Enter the provider name."))
            UI.SetFocus(Id(:name))
            next
          elsif UI.WidgetExists(Id(:phone)) && phone == ""
            # Popup::Message text
            Popup.Message(_("Enter the phone number."))
            UI.SetFocus(Id(:phone))
            next
          elsif auth_chk && username == ""
            # Popup::Message text
            Popup.Message(_("Enter the user name."))
            UI.SetFocus(Id(:username))
            next
          # password could be empty #16021
          # else if(!ask_pass && auth_chk && "" == pass)
          # {
          # 		Popup::Message(_("Enter the password."));
          # 		UI::SetFocus(`id(`passwd));
          # }
          # NM doesn't ask for password (#225793)
          elsif ask_pass && NetworkService.IsManaged
            Popup.Warning(
              _(
                "NetworkManager cannot ask for the password.\nUse KInternet (without NetworkManager) or store passwords on the system.\n"
              )
            )
            next
          elsif Builtins.filterchars(phone, phonevalidchars) != phone &&
              !# Popup::YesNo text
              Popup.YesNo(
                _(
                  "You have entered some characters that are not numbers in the phone field.\n" +
                    "\n" +
                    "Continue?"
                )
              )
            UI.SetFocus(Id(:phone))
            next
          else
            break
          end
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      if ret == :next
        Provider.Current = Builtins.union(
          Provider.Current,
          {
            "PROVIDER"       => name,
            "USERNAME"       => username,
            "PASSWORD"       => ask_pass ? "" : password,
            "PHONE"          => phone,
            "ASKPASSWORD"    => ask_pass ? "yes" : "no",
            "MODEMSUPPORTED" => type == "modem" ? "yes" : "no",
            "ISDNSUPPORTED"  => type == "isdn" ? "yes" : "no",
            "DSLSUPPORTED"   => type == "dsl" ? "yes" : "no"
          }
        )
        if type == "isdn"
          Provider.Current = Builtins.union(
            Provider.Current,
            { "ENCAP" => encap }
          )
          ISDN.provider_file = Provider.Name if ISDN.operation == :addif
        end
      end

      deep_copy(ret)
    end
  end
end
