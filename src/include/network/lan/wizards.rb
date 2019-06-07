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

require "y2network/interface_config_builder"
require "y2network/dialogs/add_interface"

module Yast
  module NetworkLanWizardsInclude
    def initialize_network_lan_wizards(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Arch"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "network/routines.rb"
      Yast.include include_target, "network/lan/address.rb"
      Yast.include include_target, "network/lan/complex.rb"
      Yast.include include_target, "network/lan/dhcp.rb"
      Yast.include include_target, "network/lan/hardware.rb"
      Yast.include include_target, "network/lan/wireless.rb"
      Yast.include include_target, "network/services/dns.rb"
      Yast.include include_target, "network/services/host.rb"
    end

    # Whole configuration of network
    # @return successfully finished
    def LanSequence
      aliases = {
        "read"  => [-> { ReadDialog() }, true],
        "main"  => -> { MainSequence("") },
        "write" => [-> { WriteDialog() }, true]
      }

      if Mode.installation || Mode.update
        aliases["packages"] = [-> { add_pkgs_to_proposal(Lan.Packages) }, true]

        sequence = {
          "ws_start" => "read",
          "read"     => { abort: :abort, back: :back, next: "main" },
          "main"     => { abort: :abort, back: :back, next: "packages" },
          "packages" => { abort: :abort, back: :back, next: "write" },
          "write"    => { abort: :abort, back: :back, next: :next }
        }

        Wizard.OpenNextBackDialog
      else
        aliases["packages"] = [-> { PackagesInstall(Lan.Packages) }, true]

        sequence = {
          "ws_start" => "read",
          "read"     => { abort: :abort, next: "main" },
          "main"     => { abort: :abort, next: "packages" },
          "packages" => { abort: :abort, next: "write" },
          "write"    => { abort: :abort, next: :next }
        }

        Wizard.OpenCancelOKDialog
        Wizard.SetDesktopTitleAndIcon("lan")
      end

      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    # Whole configuration of network but without reading and writing.
    # For use with autoinstallation and proposal
    # @param [String] mode if "proposal", NM dialog may be skipped
    # @return sequence result
    def LanAutoSequence(mode)
      caption = _("Network Card Configuration")
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("lan")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = MainSequence(mode)

      UI.CloseDialog
      ret
    end

    def MainSequence(mode)
      iface_builder = Y2Network::InterfaceConfigBuilder.new
      aliases = {
        "global"    => -> { MainDialog("global", builder: iface_builder) },
        "overview"  => -> { MainDialog("overview", builder: iface_builder) },
        "add"       => [-> { NetworkCardSequence("add", builder: iface_builder) }, true],
        "edit"      => [-> { NetworkCardSequence("edit", builder: iface_builder) }, true],
        "init_s390" => [-> { NetworkCardSequence("init_s390", builder: iface_builder) }, true]
      }

      start = "overview"
      # the NM decision is already present in the proposal.
      # see also #148485
      start = "global" if mode == "proposal"
      sequence = {
        "ws_start"  => start,
        "global"    => {
          abort: :abort,
          next:  :next,
          redraw: "global"
        },
        "overview"  => {
          abort:     :abort,
          next:      :next,
          redraw: "overview"
        },
        "add"       => { abort: :abort, next: "overview" },
        "edit"      => { abort: :abort, next: "overview" },
        "init_s390" => { abort: :abort, next: "overview" }
      }

      Sequencer.Run(aliases, sequence)
    end

    def NetworkCardSequence(action, builder:)
      ws_start = case action
      when "add"
        "add"
      when "init_s390"
        # s390 may require configuring additional modules. Which
        # enables IBM net cards for linux. Basicaly it creates
        # linux devices with common api (e.g. eth0, hsi1, ...)
        "s390"
      else
        "address"
      end

      aliases = {
        "add"     => -> { Y2Network::Dialogs::AddInterface.run(builder) },
        # TODO: first param in AddressSequence seems to be never used
        "address" => -> { AddressSequence("", builder: builder) },
        "s390"    => -> { S390Dialog(builder: builder) }
      }

      Builtins.y2milestone("ws_start %1", ws_start)

      sequence = {
        "ws_start" => ws_start,
        "add"      => { abort: :back, next: "address" },
        "address"  => { abort: :back, next: :next },
        "s390"     => { abort: :abort, next: "address" }
      }

      Sequencer.Run(aliases, sequence)
    end

    def AddressSequence(which, builder:)
      # TODO: add builder wherever needed
      aliases = {
        "address"     => -> { AddressDialog(builder: builder) },
        "hosts"       => -> { HostsMainDialog(false) },
        "s390"        => -> { S390Dialog() },
        "wire"        => -> { WirelessDialog() },
        "expert"      => -> { WirelessExpertDialog() },
        "keys"        => -> { WirelessKeysDialog() },
        "eap"         => -> { WirelessWpaEapDialog() },
        "eap-details" => -> { WirelessWpaEapDetailsDialog() },
        "commit"      => [-> { Commit(builder: builder) }, true]
      }

      ws_start = which == "wire" ? "wire" : "address" # "changedefaults";
      sequence = {
        "ws_start"    => ws_start,
        # 	"changedefaults" : $[
        # 	    `next	: "address",
        # 	],
        "address"     => {
          abort:    :abort,
          next:     "commit",
          wire:     "wire",
          hosts:    "hosts",
          s390:     "s390",
          hardware: :hardware
        },
        "s390"        => { abort: :abort, next: "address" },
        "hosts"       => { abort: :abort, next: "address" },
        "wire"        => {
          next:   "commit",
          expert: "expert",
          keys:   "keys",
          eap:    "eap",
          abort:  :abort
        },
        "expert"      => { next: "wire", abort: :abort },
        "keys"        => { next: "wire", abort: :abort },
        "eap"         => {
          next:    "commit",
          details: "eap-details",
          abort:   :abort
        },
        "eap-details" => { next: "eap", abort: :abort },
        "commit"      => { next: :next }
      }

      Sequencer.Run(aliases, sequence)
    end
  end
end
