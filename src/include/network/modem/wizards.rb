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
# File:	include/network/modem/wizards.ycp
# Package:	Network configuration
# Summary:	Modem configuration wizards
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkModemWizardsInclude
    def initialize_network_modem_wizards(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Label"
      Yast.import "Modem"
      Yast.import "Provider"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"

      Yast.include include_target, "network/provider/connection.rb"
      Yast.include include_target, "network/provider/details.rb"
      Yast.include include_target, "network/provider/dialogs.rb"
      Yast.include include_target, "network/provider/provider.rb"

      # FIXME: NI include "network/provider/wizards.ycp";

      Yast.include include_target, "network/modem/dialogs.rb"
      Yast.include include_target, "network/modem/complex.rb"
    end

    # FIXME: duplicated from provider/wizards.ycp

    def CommitProvider
      Provider.Commit
      :next
    end

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

    # Workflow of the configuration of one modem
    # @param [Boolean] detected true if modem was detected (more entries otherwise)
    # @param [Boolean] edit true in case of edit sequence
    # @return sequence result
    def OneModemProviderSequence(detected, edit)
      aliases = {
        "parameters_detected" => lambda { ModemDialog(true) },
        "parameters"          => lambda { ModemDialog(false) },
        "details"             => lambda { ModemDetailsDialog() },
        "details_detected"    => lambda { ModemDetailsDialog() },
        "providers"           => lambda { ProvidersDialog(edit) },
        "provider"            => lambda { ProviderDialog() },
        "new_provider"        => lambda { ProviderDialog() },
        "connection"          => lambda { ConnectionDialog() },
        "ipdetails"           => lambda { IPDetailsDialog() },
        "commit"              => [lambda { Commit("") }, true]
      }

      entry = "parameters"
      entry = "parameters_detected" if detected

      sequence = {
        "ws_start"            => entry,
        "parameters"          => {
          :next    => "providers",
          :Details => "details",
          :abort   => :abort
        },
        "parameters_detected" => {
          :next    => "providers",
          :Details => "details_detected",
          :abort   => :abort
        },
        "details"             => { :next => "parameters", :abort => :abort },
        "details_detected"    => {
          :next  => "parameters_detected",
          :abort => :abort
        },
        "providers"           => {
          :next  => "provider",
          :new   => "new_provider",
          :abort => :abort
        },
        "provider"            => { :next => "connection", :abort => :abort },
        "new_provider"        => { :next => "connection", :abort => :abort },
        "connection"          => {
          :IPDetails => "ipdetails",
          :next      => "commit",
          :abort     => :abort
        },
        "ipdetails"           => { :next => "connection", :abort => :abort },
        "commit"              => { :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Main workflow of the modem configuration
    # @return sequence result
    def MainSequence
      aliases = {
        "overview" => lambda { OverviewDialog() },
        "add"      => [lambda { OneModemProviderSequence(false, false) }, true],
        "edit"     => [lambda { OneModemProviderSequence(false, true) }, true],
        # "edit"		: [ ``(OneModemSequence(false)), true ],
        "Add"      => [
          lambda { OneProviderSequence(true) },
          true
        ],
        "Edit"     => [lambda { OneProviderSequence(false) }, true]
      }

      sequence = {
        "ws_start" => "overview",
        "overview" => {
          :abort => :abort,
          :next  => :next,
          :add   => "add",
          :edit  => "edit",
          :Add   => "Add",
          :Edit  => "Edit"
        },
        "add"      => { :abort => :abort, :next => "overview" },
        "edit"     => { :abort => :abort, :next => "overview" },
        "Add"      => { :abort => :abort, :next => "overview" },
        "Edit"     => { :abort => :abort, :next => "overview" }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Workflow of the configuration of one modem
    # @param [Boolean] detected true if modem was detected (more entries otherwise)
    # @return sequence result
    def OneModemSequence(detected)
      aliases = {
        "parameters_detected" => lambda { ModemDialog(true) },
        "parameters"          => lambda { ModemDialog(false) },
        "details"             => lambda { ModemDetailsDialog() },
        "details_detected"    => lambda { ModemDetailsDialog() },
        "commit"              => [lambda { Commit("modem") }, true]
      }

      entry = "parameters"
      entry = "parameters_detected" if detected

      sequence = {
        "ws_start"            => entry,
        "parameters"          => {
          :next    => "commit",
          :Details => "details",
          :abort   => :abort
        },
        "parameters_detected" => {
          :next    => "commit",
          :Details => "details_detected",
          :abort   => :abort
        },
        "details"             => { :next => "parameters", :abort => :abort },
        "details_detected"    => {
          :next  => "parameters_detected",
          :abort => :abort
        },
        "commit"              => { :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of modems
    # @return sequence result
    def ModemSequence
      aliases =
        #	"finish"	: [ ``( FinishDialog() ), true ],
        {
          "read"     => [lambda { ReadDialog() }, true],
          "main"     => lambda { MainSequence() },
          "packages" => [lambda { PackagesInstall(Modem.Packages) }, true],
          "write"    => [lambda { WriteDialog() }, true]
        }

      sequence =
        # 	"finish" : $[
        # 	    `next	: `next,
        # 	]
        {
          "ws_start" => "read",
          "read"     => { :abort => :abort, :next => "main" },
          "main"     => { :abort => :abort, :next => "packages" },
          "packages" => { :abort => :abort, :next => "write" },
          "write" =>
            #"finish"
            { :abort => :abort, :next => :next }
        }

      Wizard.OpenCancelOKDialog
      Wizard.SetDesktopIcon("modem")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    # Whole configuration of modems but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def ModemAutoSequence
      caption = _("Modem Configuration")
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("modem")
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
