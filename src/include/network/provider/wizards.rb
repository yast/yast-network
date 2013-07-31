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
# File:	clients/provider.ycp
# Package:	Network configuration
# Summary:	Provider main file
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for provider configuration.
# Uses all other files.
module Yast
  module NetworkProviderWizardsInclude
    def initialize_network_provider_wizards(include_target)
      textdomain "network"

      Yast.import "Label"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "network/provider/complex.rb"
      Yast.include include_target, "network/provider/connection.rb"
      Yast.include include_target, "network/provider/details.rb"
      Yast.include include_target, "network/provider/dialogs.rb"
      Yast.include include_target, "network/provider/provider.rb"
    end

    # Workflow of the configuration of one modem
    # @param [Boolean] country true if country list should be shown
    # @return sequence result
    def OneProviderSequence(country)
      aliases = {
        "providers"    => lambda { ProvidersDialog(false) },
        "provider"     => lambda { ProviderDialog() },
        "new_provider" => lambda { ProviderDialog() },
        "connection"   => lambda { ConnectionDialog() },
        "ipdetails"    => lambda { IPDetailsDialog() },
        "commit"       => [lambda { CommitProvider() }, true]
      }

      entry = "provider"
      entry = "providers" if country

      sequence = {
        "ws_start"     => entry,
        "providers"    => {
          :next  => "provider",
          :new   => "new_provider",
          :abort => :abort
        },
        "provider"     => { :next => "connection", :abort => :abort },
        "new_provider" => { :next => "connection", :abort => :abort },
        "connection"   => {
          :IPDetails => "ipdetails",
          :next      => "commit",
          :abort     => :abort
        },
        "ipdetails"    => { :next => "connection", :abort => :abort },
        "commit"       => { :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Main workflow of the modem configuration
    # @return sequence result
    def MainSequence
      aliases = {
        "overview" => lambda { OverviewDialog() },
        "type"     => lambda { TypeDialog() },
        "add"      => [lambda { OneProviderSequence(true) }, true],
        "edit"     => [lambda { OneProviderSequence(false) }, true]
      }

      sequence = {
        "ws_start" => "overview",
        "overview" => {
          :abort => :abort,
          :next  => :next,
          :add   => "type",
          :edit  => "edit"
        },
        "type"     => { :abort => :abort, :next => "add" },
        "add"      => { :abort => :abort, :next => "overview" },
        "edit"     => { :abort => :abort, :next => "overview" }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of modems
    # @return sequence result
    def ProviderSequence
      # Popup text
      #    string finished = _("Configure mail now?");

      aliases = {
        "read"  => [lambda { ReadDialog() }, true],
        "main"  => lambda { MainSequence() },
        "write" => [lambda { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { :abort => :abort, :next => "main" },
        "main"     => { :abort => :abort, :next => "write" },
        "write"    => { :abort => :abort, :next => :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("provider")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    # Whole configuration of modems but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def ProviderAutoSequence
      # Initial dialog caption
      caption = _("Provider Configuration")
      # Initial dialog contents
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("provider")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = MainSequence()

      UI.CloseDialog
      ret
    end
  end
end
