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
# File:
#   include/network/isdn/routines.ycp
#
# Package:
#   Configuration of network
#
# Summary:
#   helper functions for ISDN configuration
#
# Authors:
#   Karsten Keil <kkeil@suse.de>
#
#
#
#
module Yast
  module NetworkIsdnRoutinesInclude
    def initialize_network_isdn_routines(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Label"
      Yast.import "Popup"
    end

    # Return true if the given driver match i4ltyp and i4l subtype
    # @param [Hash] drv       - the driver info map
    # @param [Fixnum] i4ltyp    - the I4L TYPE
    # @param [Fixnum] i4lsubtyp - the I4L SUBTYPE
    # @return [Boolean]  - true if match false if not
    def driver_has_type(drv, i4ltyp, i4lsubtyp)
      drv = deep_copy(drv)
      ret = false

      if i4ltyp == Ops.get_integer(drv, "type", -2)
        ret = true if i4lsubtyp == Ops.get_integer(drv, "subtype", -2)
      end
      ret
    end

    # Return true if the given card match i4ltyp and i4l subtype
    # @param [Hash] card      - the card info map
    # @param [Fixnum] i4ltyp    - the I4L TYPE
    # @param [Fixnum] i4lsubtyp - the I4L SUBTYPE
    # @return [Boolean]  - true if match false if not
    def card_has_type(card, i4ltyp, i4lsubtyp)
      card = deep_copy(card)
      ret = false

      Builtins.maplist(Ops.get_list(card, "driver", [])) do |d|
        ret = true if driver_has_type(d, i4ltyp, i4lsubtyp)
      end
      ret
    end

    # Return the matching driver for i4ltyp and i4l subtype
    # @param [Hash] cdb       - cdb ISDN db
    # @param [Fixnum] i4ltyp    - the I4L TYPE
    # @param [Fixnum] i4lsubtyp - the I4L SUBTYPE
    # @return [Hash] of matching driver info
    def get_isdndriver_by_type(cdb, i4ltyp, i4lsubtyp)
      cdb = deep_copy(cdb)
      ret = {}

      Builtins.maplist(Ops.get_map(cdb, "Cards", {})) do |i, c|
        Builtins.maplist(Ops.get_list(c, "driver", [])) do |d|
          ret = deep_copy(d) if driver_has_type(d, i4ltyp, i4lsubtyp)
        end
      end
      deep_copy(ret)
    end

    # Return the matching card for i4ltyp and i4l subtype
    # @param [Hash] cdb       - cdb ISDN db
    # @param [Fixnum] i4ltyp    - the I4L TYPE
    # @param [Fixnum] i4lsubtyp - the I4L SUBTYPE
    # @return [Hash] of matching card info
    def get_isdncard_by_type(cdb, i4ltyp, i4lsubtyp)
      cdb = deep_copy(cdb)
      ret = {}

      Builtins.maplist(Ops.get_map(cdb, "Cards", {})) do |i, c|
        ret = deep_copy(c) if card_has_type(c, i4ltyp, i4lsubtyp)
      end
      deep_copy(ret)
    end

    # Return the I4L SUBTYPE from card info
    # @param [Hash] card      - map of card info
    # @return I4L SUBTYPE
    def get_i4lsubtype(card)
      card = deep_copy(card)
      ret = -1
      d = Ops.get_list(card, "driver", [])

      d = Ops.get_list(card, "drivers", []) if d == []
      ret = Ops.get_integer(
        d,
        [Ops.get_integer(card, "sel_drv", 0), "subtype"],
        -1
      )
      ret
    end

    # Return the I4L TYPE from card info
    # @param [Hash] card      - map of card info
    # @return I4L TYPE
    def get_i4ltype(card)
      card = deep_copy(card)
      ret = -1
      d = Ops.get_list(card, "driver", [])

      d = Ops.get_list(card, "drivers", []) if d == []
      ret = Ops.get_integer(
        d,
        [Ops.get_integer(card, "sel_drv", 0), "type"],
        -1
      )
      ret
    end

    # Creates a popup with test OK/ not OK and displays details on request
    # @param [Fixnum] result   - return code of the test 0 is OK
    # @param [String] details  - string of collected infos during the test
    # @return allways true
    def display_testresult(result, details)
      ret = nil
      msg = ""

      if result == 0
        # ISDN HW test result (positiv)
        msg = Builtins.sformat(_("The test was successful."))
      else
        # ISDN HW test result (negativ)
        msg = Builtins.sformat(
          _("The test was not successful.\n ReturnValue: %1\n"),
          result
        )
      end
      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(1),
            Label(msg),
            VSpacing(1),
            HBox(
              PushButton(Id(:ok), Opt(:default), Label.OKButton),
              # Button label for details about the HW test
              PushButton(Id(:detail), _("&Details"))
            ),
            VSpacing(1)
          ),
          HSpacing(1)
        )
      )
      UI.SetFocus(Id(:ok))
      ret = UI.UserInput
      Popup.Message(details) if ret == :detail
      UI.CloseDialog
      true
    end

    # Creates a popup with a selection list
    # @param [String] title   - return code of the test 0 is OK
    # @param [Array] lst  - list of items
    # @return name of the selected item
    def select_fromlist_popup(title, lst)
      lst = deep_copy(lst)
      ret = nil

      UI.OpenDialog(
        Opt(:decorated),
        HBox(
          HSpacing(1),
          VBox(
            VSpacing(1),
            ComboBox(Id(:sel), Opt(:hstretch, :notify), title, lst),
            VSpacing(1),
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            VSpacing(1)
          ),
          HSpacing(1)
        )
      )
      UI.SetFocus(Id(:ok))
      while true
        ret = UI.UserInput
        break if ret == :ok
      end
      sel = Convert.to_string(UI.QueryWidget(Id(:sel), :Value))
      UI.CloseDialog
      sel
    end
  end
end
