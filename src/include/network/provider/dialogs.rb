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
# File:	include/network/provider/dialogs.ycp
# Package:	Network configuration
# Summary:	Provider dialogs
# Authors:	Michal Svec <msvec@suse.cz>
#		Petr Blahos <pblahos@suse.cz>
#		Dan Vesely <dan@suse.cz>
#
module Yast
  module NetworkProviderDialogsInclude
    def initialize_network_provider_dialogs(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Provider"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/provider/helps.rb"
    end

    # The SelectionBox "----" divider hack
    # @param [Array] provs list of providers for the current selection
    # @param [Object] prev previously selected provider
    # @return new provider selection
    def dividerHack(provs, prev)
      provs = deep_copy(provs)
      prev = deep_copy(prev)
      p = -1
      Builtins.find(
        Convert.convert(provs, :from => "list", :to => "list <term>")
      ) do |e|
        p = Ops.add(p, 1)
        id = Ops.get_string(e, [0, 0], "x")
        id == prev
      end
      i = -1
      Builtins.find(
        Convert.convert(provs, :from => "list", :to => "list <term>")
      ) do |e|
        i = Ops.add(i, 1)
        id = Ops.get_string(e, [0, 0], "x")
        id == path(".\"--\"")
      end
      Ops.get_string(
        provs,
        [Ops.subtract(Ops.less_than(p, i) ? Ops.add(i, 1) : i, 1), 0, 0],
        "x"
      )
    end

    # Providers dialog
    # @param [Boolean] edit true in case of edit sequence
    # @return [Symbol] dialog result
    def ProvidersDialog(edit)
      type = Provider.Type
      Builtins.y2security("type=%1", type)

      # Provider dialog caption
      caption = _("Select Internet Service Provider (ISP)")

      country = Provider.LastCountry
      Builtins.y2debug("country=%1", country)
      provider = nil

      provs = []

      # Provider dialog contents
      contents = HBox(
        HSpacing(),
        VBox(
          VSpacing(1),
          HBox(
            HWeight(
              1,
              VBox(
                RadioButtonGroup(
                  Id(:radio),
                  VBox(
                    # RadioButton label
                    RadioButton(
                      Id(:custom),
                      Opt(:hstretch, :notify),
                      _("C&ustom Providers"),
                      country == "_custom"
                    ),
                    VSpacing(0.2),
                    # RadioButton label
                    RadioButton(
                      Id(:country),
                      Opt(:hstretch, :notify),
                      _("&Countries"),
                      country != "_custom"
                    )
                  )
                ),
                HBox(
                  HSpacing(3.4),
                  # SelectionBox label
                  SelectionBox(
                    Id(:countries),
                    Opt(:notify, :immediate),
                    _("C&ountry:"),
                    Provider.GetCountries
                  )
                )
              )
            ),
            HSpacing(),
            HWeight(
              1,
              HBox(ReplacePoint(Id(:providers_rep), VSpacing(1)), HSpacing(2.4))
            )
          ),
          HBox(HSpacing(3.4), Label(Id(:homepage), Opt(:hstretch), "")),
          HBox(HSpacing(3.4), Label(Id(:hotline), Opt(:hstretch), "")),
          # PushButton label (New provider)
          PushButton(Id(:new), _("Ne&w")),
          VSpacing(1)
        ),
        HSpacing()
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        Ops.get_string(@HELPS, "providers", ""),
        Label.BackButton,
        Label.NextButton
      )

      if country != "_custom"
        UI.ChangeWidget(Id(:countries), :CurrentItem, country)
      end

      # Update widgets in the ProviderDialog
      # @param [Object] re UserInput
      _UpdateProvider = lambda do |re|
        re = deep_copy(re)
        # Update custom and providers tables
        if re != :providers
          if Convert.to_boolean(UI.QueryWidget(Id(:custom), :Value))
            country = "_custom"
            UI.ChangeWidget(Id(:countries), :CurrentItem, nil)
          else
            country = Convert.to_string(
              UI.QueryWidget(Id(:countries), :CurrentItem)
            )
          end

          Builtins.y2debug("country=%1", country)
          UI.ChangeWidget(Id(:countries), :Enabled, country != "_custom")

          if country != Provider.LastCountry || !UI.WidgetExists(Id(:providers))
            provs = Provider.GetProviders(type, country, Provider.Name)
            Builtins.y2debug("provs=%1", provs)
            UI.ReplaceWidget(
              Id(:providers_rep),
              # SelectionBox label
              SelectionBox(
                Id(:providers),
                Opt(:notify, :immediate),
                _("&Providers"),
                provs
              )
            )
            Provider.LastCountry = country
          end
        end

        # Update provider info
        prev = deep_copy(provider)
        provider = UI.QueryWidget(Id(:providers), :CurrentItem)
        if Ops.is_path?(provider) && path(".\"--\"") == provider
          provider = dividerHack(provs, prev)
          UI.ChangeWidget(Id(:providers), :CurrentItem, provider)
        end
        # No provider found for the given type
        if provider == nil
          UI.ChangeWidget(Id(:homepage), :Value, "")
          UI.ChangeWidget(Id(:hotline), :Value, "")
          return
        end

        if Convert.to_boolean(UI.QueryWidget(Id(:custom), :Value))
          # Custom provider -> Select
          Provider.Select(Convert.to_string(provider))
        else
          # System provider -> SelectSystem
          Provider.SelectSystem(Convert.to_path(provider))
        end

        info = Ops.get_string(Provider.Current, "HOMEPAGE", "")
        # Label text (param is URL)
        info = Builtins.sformat(_("Home Page: %1"), info) if info != ""
        UI.ChangeWidget(Id(:homepage), :Value, info)

        info = Ops.get_string(Provider.Current, "HOTLINE", "")
        # Label text (param is phone)
        info = Builtins.sformat(_("Hot Line: %1"), info) if info != ""
        UI.ChangeWidget(Id(:hotline), :Value, info)

        nil
      end

      _UpdateProvider.call(nil)

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
        # next
        elsif ret == :next || ret == :new
          _UpdateProvider.call(ret)
          break
        # custom providers
        elsif ret == :custom || ret == :country || ret == :countries ||
            ret == :providers
          _UpdateProvider.call(ret)
          next
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end

      # New or no provider found
      if ret == :new || provider == nil
        Provider.Add(type)
      # Next
      elsif ret == :next
        # Custom provider
        if Convert.to_boolean(UI.QueryWidget(Id(:custom), :Value))
          if edit
            # Edit existent
            Provider.Edit(Convert.to_string(provider))
          else
            # Clone existent
            Provider.Clone(Convert.to_string(provider))
          end
        else
          # System provider -> SelectSystem
          Provider.CloneSystem(Convert.to_path(provider))
        end
      end

      Builtins.y2debug("country=%1", country)
      Builtins.y2debug("country=%1", Provider.LastCountry)
      deep_copy(ret)
    end
  end
end
