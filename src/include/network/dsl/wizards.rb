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
# File:	include/network/dsl/wizards.ycp
# Package:	Network configuration
# Summary:	DSL configuration wizards
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkDslWizardsInclude
    def initialize_network_dsl_wizards(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "DSL"
      Yast.import "Label"
      Yast.import "Provider"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"

      Yast.include include_target, "network/provider/connection.rb"
      Yast.include include_target, "network/provider/details.rb"
      Yast.include include_target, "network/provider/dialogs.rb"
      Yast.include include_target, "network/provider/provider.rb"

      # FIXME: NI include "network/provider/wizards.ycp";

      Yast.include include_target, "network/dsl/dialogs.rb"
      Yast.include include_target, "network/dsl/complex.rb"
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

    # Workflow of the configuration of one DSL
    # @param [Boolean] detected true if DSL was detected (more entries otherwise)
    # @param [Boolean] edit true in case of edit sequence
    # @return sequence result
    def OneDSLProviderSequence(detected, edit)
      aliases = {
        "parameters_detected" => lambda { DSLDialog() },
        "parameters"          => lambda { DSLDialog() },
        # FIXME: not used?	"details"		: ``(DSLDetailsDialog()),
        # FIXME: not used?	"details_detected"	: ``(DSLDetailsDialog()),
        "providers"           => lambda(
        ) do
          ProvidersDialog(edit)
        end,
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
          :next  => "providers",
          # FIXME: not used? `Details: "details",
          :abort => :abort
        },
        "parameters_detected" => {
          :next  => "providers",
          # FIXME: not used? `Details: "details_detected",
          :abort => :abort
        },
        # FIXME: not used? "details"   : $[
        # FIXME: not used? `next   : "parameters",
        # FIXME: not used? `abort  : `abort
        # FIXME: not used? ],
        # FIXME: not used? "details_detected" : $[
        # FIXME: not used? `next   : "parameters_detected",
        # FIXME: not used? `abort  : `abort
        # FIXME: not used? ],
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

    # Main workflow of the DSL configuration
    # @return sequence result
    def DSLMainSequence
      aliases = {
        "overview" => lambda { OverviewDialog() },
        "add"      => [lambda { OneDSLProviderSequence(false, false) }, true],
        "edit"     => [lambda { OneDSLProviderSequence(false, true) }, true],
        # "edit"		: [ ``(OneDSLSequence(false)), true ],
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

    # Workflow of the configuration of one DSL
    # @param [Boolean] detected true if DSL was detected (more entries otherwise)
    # @return sequence result
    def OneDSLSequence(detected)
      aliases = {
        "parameters_detected" => lambda { DSLDialog() },
        "parameters"          => lambda { DSLDialog() },
        # FIXME: not used? "details"		: ``(DSLDetailsDialog()),
        # FIXME: not used? "details_detected"	: ``(DSLDetailsDialog()),
        "commit"              => [
          lambda { Commit("dsl") },
          true
        ]
      }

      entry = "parameters"
      entry = "parameters_detected" if detected

      sequence = {
        "ws_start"            => entry,
        "parameters"          => {
          :next  => "commit",
          # FIXME: not used? `Details: "details",
          :abort => :abort
        },
        "parameters_detected" => {
          :next  => "commit",
          # FIXME: not used? `Details: "details_detected",
          :abort => :abort
        },
        # FIXME: not used? "details"   : $[
        # FIXME: not used? `next   : "parameters",
        # FIXME: not used? `abort  : `abort
        # FIXME: not used? ],
        # FIXME: not used? "details_detected" : $[
        # FIXME: not used? `next   : "parameters_detected",
        # FIXME: not used? `abort  : `abort
        # FIXME: not used? ],
        "commit"              => {
          :next => :next
        }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of DSL
    # @return sequence result
    def DSLSequence
      aliases =
        #	"finish"	: [ ``( FinishDialog() ), true ],
        {
          "read"     => [lambda { ReadDialog() }, true],
          "main"     => lambda { DSLMainSequence() },
          "packages" => [lambda { PackagesInstall(DSL.Packages) }, true],
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
      Wizard.SetDesktopIcon("dsl")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    # Whole configuration of DSL but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def DSLAutoSequence
      caption = _("DSL Configuration")
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("dsl")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = DSLMainSequence()

      UI.CloseDialog
      ret
    end
  end
end
