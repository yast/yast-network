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
# File:	include/network/summary.ycp
# Package:	Network configuration
# Summary:	Summary and overview functions
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# All config settings are stored in a global variable Devices.
# All hardware settings are stored in a global variable Hardware.
# Deleted devices are in the global list DELETED.
module Yast
  module NetworkSummaryInclude
    def initialize_network_summary(_include_target)
      textdomain "network"

      Yast.import "String"
      Yast.import "NetworkInterfaces"
    end

    # Create list of Table items
    # @param [Array<String>] types list of types
    # @param [String] cur current type
    # @return Table items
    def BuildTypesList(types, cur)
      types = deep_copy(types)
      Builtins.maplist(types) do |t|
        Item(Id(t), NetworkInterfaces.GetDevTypeDescription(t, false), t == cur)
      end
    end

    # Create table widget for the overview screens with correct spacings
    # @param [String] caption table caption
    # @param [Yast::Term] header table header
    # @param [Array] contents table contents
    # @param [Boolean] first table is first of the two tables
    # @return table widget
    def OverviewTableContents(caption, header, contents, first)
      header = deep_copy(header)
      contents = deep_copy(contents)
      addbutton = nil
      editbutton = nil
      deletebutton = nil
      if first
        # Pushbutton label
        addbutton = PushButton(Id(:add), Opt(:key_F3), _("A&dd"))
        # Pushbutton label
        editbutton = PushButton(Id(:edit), Opt(:key_F4), _("&Edit"))
        # Pushbutton label
        deletebutton = PushButton(Id(:delete), Opt(:key_F5), _("De&lete"))
      else
        # Pushbutton label (different shortcut)
        addbutton = PushButton(Id(:Add), _("&Add"))
        # Pushbutton label (different shortcut)
        editbutton = PushButton(Id(:Edit), _("Ed&it"))
        # Pushbutton label (different shortcut)
        deletebutton = PushButton(Id(:Delete), _("Dele&te"))
      end

      HBox(
        HSpacing(1.5),
        VBox(
          VSpacing(0.0),
          caption != "" ? Left(Heading(caption)) : VSpacing(0.0),
          Table(Id(first ? :table : :Table), Opt(:notify), header, contents),
          VSpacing(0.4),
          HBox(Opt(:hstretch), addbutton, editbutton, deletebutton),
          VSpacing(0.5)
        ),
        HSpacing(1.5)
      )
    end

    # Create table widget for the overview screens
    # @param [Yast::Term] header table header
    # @param [Array] contents table contents
    # @return table widget
    def OverviewTable(header, contents)
      header = deep_copy(header)
      contents = deep_copy(contents)
      VBox(VSpacing(0.5), OverviewTableContents("", header, contents, true))
    end

    # Create two table widgets for the overview screens
    # @param [String] caption1 first table caption
    # @param [Yast::Term] header1 first table header
    # @param [Array] contents1 first table contents
    # @param [String] caption2 second table caption
    # @param [Yast::Term] header2 second table header
    # @param [Array] contents2 second table contents
    # @return table widget
    def OverviewTableDouble(caption1, header1, contents1, caption2, header2, contents2)
      header1 = deep_copy(header1)
      contents1 = deep_copy(contents1)
      header2 = deep_copy(header2)
      contents2 = deep_copy(contents2)
      VBox(
        VSpacing(0.5),
        OverviewTableContents(caption1, header1, contents1, true),
        OverviewTableContents(caption2, header2, contents2, false)
      )
    end
  end
end
