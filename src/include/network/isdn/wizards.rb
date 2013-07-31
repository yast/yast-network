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
# File:	include/network/isdn/wizards.ycp
# Package:	Configuration of network
# Summary:	ISDN configuration wizards
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkIsdnWizardsInclude
    def initialize_network_isdn_wizards(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "Provider"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"

      Yast.include include_target, "network/isdn/lowlevel.rb"
      Yast.include include_target, "network/isdn/complex.rb"
      Yast.include include_target, "network/isdn/interface.rb"
      Yast.include include_target, "network/isdn/ip.rb"
      Yast.include include_target, "network/isdn/ifdetails.rb"

      # include "network/provider/wizards.ycp";
      Yast.include include_target, "network/provider/details.rb"
      Yast.include include_target, "network/provider/dialogs.rb"
      Yast.include include_target, "network/provider/connection.rb"
      Yast.include include_target, "network/provider/provider.rb"
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
    def ISDNSequence
      aliases =
        #	"finish": [ ``( Finished(ISDN::Modified(), FinishedMailText(), "mail", ["dialup"]) ), true ],
        {
          "read"  => [lambda { ReadDialog() }, true],
          "main"  => lambda { MainSequence() },
          "write" => [lambda { WriteDialog() }, true]
        }

      sequence =
        #	"finish" : $[
        #	    `next	: `next,
        #	]
        {
          "ws_start" => "read",
          "read"     => { :abort => :abort, :next => "main" },
          "main"     => { :abort => :abort, :next => "write" },
          "write" =>
            #	    `next	: "finish"
            { :abort => :abort, :next => :next }
        }

      Wizard.OpenCancelOKDialog
      Wizard.SetDesktopTitleAndIcon("isdn")

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end
    def ISDNAutoSequence
      # main srceen title
      caption = _("ISDN Configuration")
      # static text
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("isdn")
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
    def MainSequence
      aliases = {
        "overview" => lambda { OverviewDialog() },
        "add"      => [lambda { OneISDNSequence("other") }, true],
        "edit"     => lambda { isdn_lowlevel },
        "Add"      => [lambda { OneISDNSequence("selif_add") }, true],
        "Editif"   => [lambda { OneISDNSequence("edit_if") }, true],
        "Editprov" => [lambda { OneProviderSequence(false) }, true],
        "commit"   => lambda { Commit() }
      }

      sequence = {
        "ws_start" => "overview",
        "overview" => {
          :abort    => :abort,
          :next     => :next,
          :add      => "add",
          :edit     => "edit",
          :Add      => "Add",
          :Editif   => "Editif",
          :Editprov => "Editprov"
        },
        "add"      => { :abort => :abort, :next => "overview" },
        "edit"     => { :abort => :abort, :next => "commit" },
        "Add"      => { :abort => :abort, :next => "overview" },
        "Editif"   => { :abort => :abort, :next => "overview" },
        "Editprov" => { :abort => :abort, :next => "commit" },
        "commit"   => { :next => "overview" }
      }

      Sequencer.Run(aliases, sequence)
    end
    def OneISDNSequence(entry)
      aliases = {
        "lowlevel"    => lambda { isdn_lowlevel },
        "other"       => lambda { SelectISDNCard() },
        "selif_add"   => lambda { isdn_if_sel(:add) },
        "selif_hw"    => lambda { isdn_if_sel(:hw) },
        "add_if"      => [lambda { OneISDNIFSequence("add_if") }, true],
        "edit_if"     => [lambda { OneISDNIFSequence("edit_if") }, true],
        "addprovider" => [lambda { OneProviderSequence(true) }, true],
        "commit"      => [lambda { Commit() }, true]
      }

      sequence = {
        "ws_start"    => entry,
        "lowlevel"    => { :next => "selif_hw", :abort => :abort },
        "other"       => { :next => "lowlevel", :abort => :abort },
        "selif_hw"    => {
          :next        => "commit",
          :AddProvider => "addprovider",
          :AddSyncPPP  => "add_if",
          :AddRawIP    => "add_if",
          :abort       => :abort
        },
        "selif_add"   => {
          :next        => "commit",
          :AddProvider => "addprovider",
          :AddSyncPPP  => "add_if",
          :AddRawIP    => "add_if",
          :abort       => :abort
        },
        "add_if"      => { :next => "addprovider", :abort => :abort },
        "edit_if"     => { :next => "commit", :abort => :abort },
        "addprovider" => { :next => "commit", :abort => :abort },
        "commit"      => { :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end
    def OneISDNIFSequence(entry)
      aliases = {
        "add_if"      => lambda { interface_dialog },
        "edit_if"     => lambda { interface_dialog },
        "ip_add"      => lambda { IPDialog() },
        "ip_edit"     => lambda { IPDialog() },
        "detail_add"  => lambda { IFDetailDialog() },
        "detail_edit" => lambda { IFDetailDialog() },
        "commit"      => [lambda { Commit() }, true]
      }

      sequence = {
        "ws_start"    => entry,
        "add_if"      => {
          :next   => "ip_add",
          :detail => "detail_add",
          :abort  => :abort
        },
        "edit_if"     => {
          :next   => "ip_edit",
          :detail => "detail_edit",
          :abort  => :abort
        },
        "ip_add"      => { :next => :next, :abort => :abort },
        "detail_add"  => { :next => "add_if", :abort => :abort },
        "ip_edit"     => { :next => "commit", :abort => :abort },
        "detail_edit" => { :next => "edit_if", :abort => :abort },
        "commit"      => { :next => :next }
      }

      Sequencer.Run(aliases, sequence)
    end
  end
end
