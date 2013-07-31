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
#   include/network/isdn/lowlovel.ycp
#
# Package:
#   Configuration of network
#
# Summary:
#   ISDN configuration dialogs
#
# Authors:
#   Michal Svec <msvec@suse.cz>
#
#
module Yast
  module NetworkIsdnLowlevelInclude
    def initialize_network_isdn_lowlevel(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "CWM"
      Yast.import "ISDN"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "network/isdn/routines.rb"
      Yast.include include_target, "network/widgets.rb"
    end

    # Helper to create a SelectionBox item list
    # of ISDN cards for a specific vendor
    # @param [Fixnum] vendor  - vendor id if -1 all vendors
    # @param [Fixnum] defcard - default card, if -1 first card
    # @return item list: list<term (term (?), ?, boolean)>

    def ISDNCards4Vendor(vendor, defcard)
      cards = Builtins.maplist(Ops.get_map(ISDN.ISDNCDB, "Cards", {})) do |i, c|
        c
      end
      first = defcard == -1
      n_id = ""

      if vendor == -1
        cards = Builtins.sort(cards) do |x, y|
          Ops.less_than(
            Ops.get_integer(x, "VendorRef", -1),
            Ops.get_integer(y, "VendorRef", -1)
          )
        end
        n_id = "longname"
      else
        cards = Builtins.filter(cards) do |c|
          Ops.get_integer(c, "VendorRef", -1) == vendor
        end
        n_id = "name"
      end
      itemlist = Builtins.maplist(cards) do |c|
        sel = false
        if first
          defcard = -2
          sel = true
          first = false
        else
          sel = defcard == Ops.get_integer(c, "CardID", -1)
        end
        Item(
          Id(Ops.get_integer(c, "CardID", -1)),
          Ops.get_string(c, n_id, "unknown"),
          sel
        )
      end
      deep_copy(itemlist)
    end

    # Dialog to select a Card from the database
    # return dialog result

    def SelectISDNCard
      # Manual selection caption
      caption = _("Manual ISDN Card Selection")

      # Manual selection help
      helptext = _(
        "<p>Select the ISDN card to configure. Filter cards for \nparticular vendors by selecting a vendor.</p>"
      )

      if ISDN.ISDNCDB == {}
        ISDN.ISDNCDB = Convert.to_map(SCR.Read(path(".probe.cdb_isdn")))
      end

      typ = Builtins.tointeger(
        Ops.get_string(ISDN.hw_device, "PARA_TYPE", "-1")
      )
      subtyp = Builtins.tointeger(
        Ops.get_string(ISDN.hw_device, "PARA_SUBTYPE", "-1")
      )
      cur_card = get_isdncard_by_type(ISDN.ISDNCDB, typ, subtyp)

      vendor = Ops.get_integer(cur_card, "VendorRef", -1)
      card = Ops.get_integer(cur_card, "CardID", -1)

      vendors = Builtins.maplist(Ops.get_map(ISDN.ISDNCDB, "Vendors", {})) do |i, v|
        Item(Id(i), Ops.get_string(v, "name", "unknown"), i == vendor)
      end
      vendors = Builtins.prepend(vendors, Item(Id(-1), _("All"), -1 == vendor))

      cards = ISDNCards4Vendor(vendor, card)

      # Manual selection contents
      contents = VBox(
        VSpacing(0.5),
        HBox(
          # Selection box label
          SelectionBox(Id(:vendor), Opt(:notify), _("Select &Vendor"), vendors),
          # Selection box label
          ReplacePoint(
            Id(:rpc),
            SelectionBox(
              Id(:cards),
              Opt(:notify),
              _("Se&lect ISDN Card"),
              cards
            )
          )
        ),
        VSpacing(0.5),
        # Text entry field
        TextEntry(Id(:search), Opt(:notify), _("&Search")),
        VSpacing(0.5)
      )

      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      UI.SetFocus(Id(:vendor))

      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          break if Popup.ReallyAbort(true)
          next
        elsif ret == :search
          entry = Convert.to_string(UI.QueryWidget(Id(:search), :Value))

          next if Builtins.size(entry) == 0

          l = Builtins.filter(cards) do |e|
            Builtins.tolower(
              Builtins.substring(
                Ops.get_string(e, 1, ""),
                0,
                Builtins.size(entry)
              )
            ) ==
              Builtins.tolower(entry)
          end
          if Ops.greater_than(Builtins.size(l), 0)
            card = Ops.get_integer(l, [0, 0, 0], 0)
            UI.ChangeWidget(Id(:cards), :CurrentItem, card)
            UI.ReplaceWidget(
              Id(:rpc),
              SelectionBox(Id(:cards), _("Se&lect ISDN Card"), cards)
            )
            next
          end
          m = Builtins.filter(Ops.get_map(ISDN.ISDNCDB, "Cards", {})) do |i, c|
            Builtins.tolower(
              Builtins.substring(
                Ops.get_string(c, "longname", ""),
                0,
                Builtins.size(entry)
              )
            ) ==
              Builtins.tolower(entry)
          end
          if Builtins.size(m) == 0
            m = Builtins.filter(Ops.get_map(ISDN.ISDNCDB, "Cards", {})) do |i, c|
              Ops.less_or_equal(
                0,
                Builtins.find(
                  Builtins.tolower(Ops.get_string(c, "longname", "")),
                  Builtins.tolower(entry)
                )
              )
            end
          end
          next if Builtins.size(m) == 0
          ml = Builtins.maplist(
            Convert.convert(m, :from => "map", :to => "map <integer, map>")
          ) { |i, c| c }
          m = Ops.get(ml, 0, {})

          card = Ops.get_integer(m, "CardID", -1)
          vendor = Ops.get_integer(m, "VendorRef", -1)
          cards = ISDNCards4Vendor(vendor, card)
          # Selection box title
          UI.ChangeWidget(Id(:vendor), :CurrentItem, vendor)
          UI.ReplaceWidget(
            Id(:rpc),
            SelectionBox(Id(:cards), _("Se&lect ISDN Card"), cards)
          )
          card = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
        elsif ret == :vendor
          v = Convert.to_integer(UI.QueryWidget(Id(:vendor), :CurrentItem))
          card = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
          next if v == vendor
          card = -1 if vendor != -1 && v != -1
          vendor = v
          cards = ISDNCards4Vendor(vendor, card)
          UI.ReplaceWidget(
            Id(:rpc),
            SelectionBox(Id(:cards), _("Se&lect ISDN Card"), cards)
          )
          card = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
        elsif ret == :cards
          card = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
        elsif ret == :back
          break
        elsif ret == :next
          break
        else
          Builtins.y2error("Unexpected return code: %1", ret)
          next
        end
      end

      if ret == :next
        card = Convert.to_integer(UI.QueryWidget(Id(:cards), :CurrentItem))
        cur_card = Ops.get_map(ISDN.ISDNCDB, ["Cards", card], {})
        ISDN.hw_device = Builtins.union(
          ISDN.hw_device,
          {
            "PARA_TYPE"    => Builtins.sformat("%1", get_i4ltype(cur_card)),
            "PARA_SUBTYPE" => Builtins.sformat("%1", get_i4lsubtype(cur_card)),
            "NAME"         => Builtins.sformat(
              "%1",
              Ops.get_string(cur_card, "name", "unknown")
            )
          }
        )
      end

      deep_copy(ret)
    end

    # Dialog for ISDN Parameters
    # @param [Hash] drv      driver data
    # @return [Yast::Term] with dialog data
    def Card_Parameter(drv)
      drv = deep_copy(drv)
      contens = HBox()
      typ = Builtins.tointeger(
        Ops.get_string(ISDN.hw_device, "PARA_TYPE", "-1")
      )
      found = false

      return deep_copy(contens) if drv == nil

      if typ == 8005
        # CheckBox label
        contens = Builtins.add(
          contens,
          CheckBox(Id(:t1b), _("&T1B Version"), false)
        )
      end
      io = Ops.get_list(drv, "IO", [])
      irq = Ops.get_list(drv, "IRQ", [])
      mem = Ops.get_list(drv, "MEMBASE", [])
      if 0 ==
          Ops.add(
            Ops.add(Builtins.size(io), Builtins.size(irq)),
            Builtins.size(mem)
          )
        return deep_copy(contens)
      end
      if io != []
        default_io = Builtins.tointeger(Ops.get(io, 0, "0"))
        cur_io = Ops.get_string(ISDN.hw_device, "PARA_IO", "")
        default_io = Builtins.tointeger(cur_io) if cur_io != ""
        iol = []
        found = false
        Builtins.maplist(io) do |v|
          tmp = Builtins.tointeger(v) == default_io
          found = true if tmp
          iol = Builtins.add(iol, Item(Id(v), v, tmp))
        end
        if !found || Ops.greater_than(2, Builtins.size(io))
          if !found
            iol = Builtins.add(
              iol,
              Item(
                Id(Builtins.tohexstring(default_io)),
                Builtins.tohexstring(default_io),
                true
              )
            )
          end
          # ComboBox label
          contens = Builtins.add(
            contens,
            ComboBox(Id(:IOADR), Opt(:editable), _("&IO Address"), iol)
          )
        else
          # ComboBox label
          contens = Builtins.add(
            contens,
            ComboBox(Id(:IOADR), _("&IO Address"), iol)
          )
        end
      end
      if irq != []
        default_irq = Builtins.tointeger(Ops.get(irq, 2, "5"))
        cur_irq = Ops.get_string(ISDN.hw_device, "PARA_IRQ", "")
        default_irq = Builtins.tointeger(cur_irq) if cur_irq != ""
        irql = []
        found = false
        Builtins.maplist(irq) do |v|
          tmp = Builtins.tointeger(v) == default_irq
          found = true if tmp
          irql = Builtins.add(irql, Item(Id(v), v, tmp))
        end
        if !found || Ops.greater_than(2, Builtins.size(irq))
          if !found
            irql = Builtins.add(
              irql,
              Item(
                Id(Builtins.sformat("%1", default_irq)),
                Builtins.sformat("%1", default_irq),
                true
              )
            )
          end
          # ComboBox label
          contens = Builtins.add(
            contens,
            ComboBox(Id(:IRQ), Opt(:editable), _("IR&Q"), irql)
          )
        else
          # ComboBox label
          contens = Builtins.add(contens, ComboBox(Id(:IRQ), _("IR&Q"), irql))
        end
      end
      if mem != []
        default_mem = Builtins.tointeger(Ops.get(mem, 0, "0"))
        cur_memb = Ops.get_string(ISDN.hw_device, "PARA_MEMBASE", "")
        default_mem = Builtins.tointeger(cur_memb) if cur_memb != ""
        meml = []
        found = false
        Builtins.maplist(mem) do |v|
          tmp = Builtins.tointeger(v) == default_mem
          found = true if tmp
          meml = Builtins.add(meml, Item(Id(v), v, tmp))
        end
        if !found || Ops.greater_than(2, Builtins.size(mem))
          if !found
            meml = Builtins.add(
              meml,
              Item(
                Id(Builtins.tohexstring(default_mem)),
                Builtins.tohexstring(default_mem),
                true
              )
            )
          end
          # ComboBox label
          contens = Builtins.add(
            contens,
            ComboBox(Id(:MEMBASE), Opt(:editable), _("&Membase"), meml)
          )
        else
          # ComboBox label
          contens = Builtins.add(
            contens,
            ComboBox(Id(:MEMBASE), _("&Membase"), meml)
          )
        end
      end
      # static label for HW parameter
      HBox(HWeight(30, Left(Label(_("Parameter")))), HWeight(70, Left(contens)))
    end

    # Helper enables protocols depending on driver
    # @param [Hash] drv   driver data
    def EnableProtocols(drv)
      drv = deep_copy(drv)
      protocol = Ops.get_list(drv, "protocol", [])
      UI.ChangeWidget(Id("1tr6"), :Enabled, Builtins.contains(protocol, "1TR6"))
      UI.ChangeWidget(Id("euro"), :Enabled, Builtins.contains(protocol, "DSS1"))
      UI.ChangeWidget(Id("ni1"), :Enabled, Builtins.contains(protocol, "NI1"))
      UI.ChangeWidget(
        Id("leased"),
        :Enabled,
        Builtins.contains(protocol, "LEASED")
      )

      nil
    end

    # Helper creates a Combobox with a description label to select a
    # driver from list drv. The label is the description of the
    # current selected driver.
    # @param [Array] drv    list of available drivers for the card
    # @param [String] desc description of the actual driver
    # @return [Yast::Term] of the created box
    def create_drv_term(drv, desc)
      drv = deep_copy(drv)
      ret = nil

      ret = HBox(
        # ComboBox label to select a driver
        HWeight(
          29,
          ComboBox(Id(:DrvBox), Opt(:hstretch, :notify), _("Dri&ver"), drv)
        ),
        HSpacing(1),
        HWeight(70, Label(Id(:DrvDesc), desc))
      )
      deep_copy(ret)
    end

    # Main dialog to select a driver and setup the ISDN parameter
    # If needed HW parameter can be set
    # Line parameter like AREACODE and DIALPREFIX can be entered.
    # return dialog result

    def isdn_lowlevel
      # PREPARE VARIABLES

      if ISDN.ISDNCDB == {}
        ISDN.ISDNCDB = Convert.to_map(SCR.Read(path(".probe.cdb_isdn")))
      end
      Builtins.y2debug("ISDN::ISDNCDB %1", ISDN.ISDNCDB)

      _CurrentDrvIndex = -1
      t1b = false
      _CardName = ""
      protocol = Ops.get_string(ISDN.hw_device, "PROTOCOL", "euro")
      areacode = Ops.get_string(ISDN.hw_device, "AREACODE", "")
      dialprefix = Ops.get_string(ISDN.hw_device, "DIALPREFIX", "")
      isdnlog = Ops.get_string(ISDN.hw_device, "ISDNLOG_START", "yes") == "yes"
      startmode = Ops.get_string(ISDN.hw_device, "STARTMODE", "auto")

      _Default_TYPE = Builtins.tointeger(
        Ops.get_string(ISDN.hw_device, "PARA_TYPE", "-1")
      )
      _Default_SUBTYPE = Builtins.tointeger(
        Ops.get_string(ISDN.hw_device, "PARA_SUBTYPE", "-1")
      )
      # Special Handling AVM T1
      if _Default_TYPE == 8005
        if _Default_SUBTYPE == 1
          _Default_SUBTYPE = 0
          t1b = true
        elsif _Default_SUBTYPE == 3
          _Default_SUBTYPE = 2
          t1b = true
        end
      end

      cur_card = get_isdncard_by_type(
        ISDN.ISDNCDB,
        _Default_TYPE,
        _Default_SUBTYPE
      )
      cur_vendor = Ops.get_map(
        ISDN.ISDNCDB,
        ["Vendors", Ops.get_integer(cur_card, "VendorRef", -1)],
        {}
      )

      Builtins.y2debug("DefaultTYPE : %1/%2", _Default_TYPE, _Default_SUBTYPE)

      _CardDrivers = Ops.get_list(cur_card, "driver", [])
      _DriverCnt = Builtins.size(_CardDrivers)
      id = -1
      _DrvList = Builtins.maplist(
        Convert.convert(_CardDrivers, :from => "list", :to => "list <map>")
      ) do |d|
        id = Ops.add(id, 1)
        _Tmp = driver_has_type(d, _Default_TYPE, _Default_SUBTYPE)
        _CurrentDrvIndex = id if _Tmp
        Item(Id(id), Ops.get_string(d, "name", "unknown"), _Tmp)
      end
      Builtins.y2debug("CurrentDrvIndex %1", _CurrentDrvIndex)
      Builtins.y2debug("DrvList %1", _DrvList)

      if Builtins.contains(
          Ops.get_list(_CardDrivers, [_CurrentDrvIndex, "features"], []),
          "DSLONLY"
        )
        ISDN.only_dsl = true
      else
        ISDN.only_dsl = false
      end

      # DIALOG TEXTS
      # title for dialog
      caption = Builtins.sformat(
        _("ISDN Low-Level Configuration for %1%2"),
        ISDN.type,
        ISDN.device
      )

      Ops.set(
        @widget_descr,
        "STARTMODE",
        MakeStartmode(["auto", "hotplug", "manual", "off"])
      )

      helptext = ""

      if !Builtins.contains(
          ["PCI", "PCMCIA", "USB"],
          Ops.get_string(cur_card, "bus", "")
        )
        helptext = Ops.add(
          helptext,
          # helptext text 1/7
          _(
            "<p>If you have an old legacy ISA card, you can enter values for\n" +
              "IO port or memory addresses and the used interrupt.\n" +
              "For the correct values, check with your technical manual or contact your salesman.</p>\n"
          )
        )
      end

      helptext = Ops.add(
        helptext,
        # helptext text 2/7
        _(
          "<p><b>Start Mode: </b>  With <b>OnBoot</b>, the driver is loaded during\n" +
            "system boot. For <b>Manual</b>, the driver must be started with the\n" +
            "<b>rcisdn start</b> command. Only the user root can do this.\n" +
            "<b>HotPlug</b> is a special case for PCMCIA and USB devices.</p>\n"
        )
      )

      if Ops.less_than(1, Builtins.size(_DrvList))
        helptext = Ops.add(
          helptext,
          # helptext text 3/7
          _(
            "<p>Multiple drivers exist for your ISDN card.\nSelect one from the list.</p>\n"
          )
        )
      end

      helptext = Ops.add(
        helptext,
        # helptext text 4/7
        _(
          "<p><b>ISDN Protocol: </b>In most cases, the protocol is Euro-ISDN.</p>"
        )
      )

      helptext = Ops.add(
        helptext,
        # helptext text 5/7
        _(
          "<p><b>Area Code: </b> Enter your local area code for the ISDN\nline here, without a leading zero and without a country prefix.</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # helptext text 6/7
        _(
          "<p><b>Dial Prefix: </b> If you need a prefix to get an public line, \nenter it here. This is only used on a internal S0 bus and the most common one is \"0\".</p>\n"
        )
      )

      helptext = Ops.add(
        helptext,
        # helptext text 7/7
        _(
          "<p>If you do not want to log all your ISDN traffic, uncheck <b>Start ISDN Log</b>.</p>"
        )
      )

      helptext = Ops.add(
        helptext,
        Ops.get_string(@widget_descr, ["STARTMODE", "help"], "")
      )

      # DIALOG CONTENTS

      # USERCONTROL is unused here but it will make indexing consistent
      # until we get a better CWM API
      widgets = CWM.CreateWidgets(["USERCONTROL", "STARTMODE"], @widget_descr)

      _ISDN_protocol = VSquash(
        # Frame title
        Frame(
          _("ISDN Protocol"),
          RadioButtonGroup(
            Id(:protocol),
            VBox(
              # RadioButton label for ISDN protocols
              Left(
                RadioButton(
                  Id("euro"),
                  _("&Euro-ISDN (EDSS1)"),
                  protocol == "euro"
                )
              ),
              # RadioButton label for ISDN protocols
              Left(RadioButton(Id("1tr6"), _("1TR&6"), protocol == "1tr6")),
              # RadioButton label for ISDN protocols
              Left(
                RadioButton(
                  Id("leased"),
                  _("&Leased Line"),
                  protocol == "leased"
                )
              ),
              # RadioButton label for ISDN protocols
              Left(RadioButton(Id("ni1"), _("NI&1"), protocol == "ni1")),
              VStretch()
            )
          )
        )
      )

      _CountryCodes = {
        # Country name
        "+43"  => _("Austria"),
        # Country name
        "+49"  => _("Germany"),
        # Country name
        "+352" => _("Luxemburg"),
        # Country name
        "+31"  => _("Netherlands"),
        # Country name
        "+47"  => _("Norway"),
        # Country name
        "+48"  => _("Poland"),
        # Country name
        "+421" => _("Slovakia"),
        # Country name
        "+41"  => _("Switzerland"),
        # Country name
        "+420" => _("Czech Republic"),
        # Country name
        "+1"   => _("North America")
      }

      ccode = ""
      newcc = "+49" # default ???

      if areacode != ""
        c = Builtins.splitstring(areacode, " ")
        if Ops.greater_or_equal(2, Builtins.size(c))
          newcc = Ops.get_string(c, 0, "")
          areacode = Ops.get_string(c, 1, "")
        elsif 1 == Builtins.size(c)
          if "+" == Builtins.substring(areacode, 0, 1)
            newcc = areacode
            areacode = ""
          end
        end
      end
      if !Builtins.haskey(_CountryCodes, newcc)
        ccode = "-1"
      else
        ccode = newcc
      end

      countries = Builtins.maplist(
        Convert.convert(
          _CountryCodes,
          :from => "map",
          :to   => "map <string, string>"
        )
      ) { |i, n| Item(Id(i), n, i == ccode) }
      countries = Builtins.sort(
        Convert.convert(countries, :from => "list", :to => "list <term>")
      ) do |x, y|
        Ops.less_than(Ops.get_string(x, 1, ""), Ops.get_string(y, 1, ""))
      end
      # other country in list
      countries = Builtins.add(
        countries,
        Item(Id("-1"), _("Other"), "-1" == ccode)
      )
      ccode = newcc

      _ISDN_area = VBox(
        HBox(
          # ComboBoxlabel for country list
          HWeight(
            25,
            ComboBox(Id(:Country), Opt(:notify), _("&Country"), countries)
          ),
          HSpacing(1),
          # TextEntry label for phone network Areacode (german Vorwahl)
          HWeight(24, TextEntry(Id(:CCode), _("Co&de"), ccode))
        ),
        VSpacing(0.4),
        HBox(
          # TextEntry label for phone network Areacode (german Vorwahl)
          HWeight(25, TextEntry(Id(:areacode), _("&Area Code"), areacode)),
          # TextEntry label for phone number prefix to get a public line (german Amtsholziffer)
          HSpacing(1),
          HWeight(24, TextEntry(Id(:dialprefix), _("&Dial Prefix"), dialprefix))
        ),
        VSpacing(0.4),
        # CheckBox label
        Left(CheckBox(Id(:ilog), _("Start &ISDN Log"), isdnlog))
      )

      # unfortunatly the desc string comes direcly from libhd and is untranslated
      # as workaround I make this local translation map for it, since here are
      # not so much entries
      drvdesc = {
        # short description of card feature
        "binary only CAPI with FAX G3"           => _(
          "binary only CAPI with FAX G3"
        ),
        # short description of card feature
        "under development"                      => _(
          "under development"
        ),
        # short description of card feature
        "OpenSource without Fax G3"              => _(
          "OpenSource without FAX G3"
        ),
        # short description of card feature
        "binary only CAPI with FAX G3 and DSL"   => _(
          "binary only CAPI with FAX G3 and DSL"
        ),
        # short description of card feature
        "DSL only card with CAPI2.0"             => _(
          "DSL only card with CAPI2.0"
        ),
        # short description of card feature
        "Bluetooth Dongle,need ISDN Accesspoint" => _(
          "Bluetooth Dongle, need ISDN Access point"
        )
      }

      desc = Ops.get_string(_CardDrivers, [_CurrentDrvIndex, "description"], "")
      desc = Ops.get_string(drvdesc, desc, desc) if desc != ""

      _ISDN_driver = create_drv_term(_DrvList, desc)

      # frame title
      _ISDN_card = Frame(
        _("ISDN Card Information"),
        VBox(
          HBox(
            HWeight(
              30,
              VBox(
                Left(Label(Id(:Vend), _("Vendor"))),
                Left(Label(Id(:Card), _("ISDN Card")))
              )
            ),
            HWeight(
              70,
              VBox(
                Left(
                  Label(
                    Id(:VendN),
                    Ops.get_string(cur_vendor, "name", "unknown")
                  )
                ),
                Left(
                  Label(Id(:CardN), Ops.get_string(cur_card, "name", "unknown"))
                )
              )
            )
          ),
          Card_Parameter(Ops.get_map(_CardDrivers, _CurrentDrvIndex, {}))
        )
      )

      if Ops.get_string(cur_card, "bus", "") == "USB" ||
          Ops.get_string(cur_card, "bus", "") == "PCMCIA"
        startmode = "hotplug"
      end

      if ISDN.only_dsl
        _ISDN_protocol = HSpacing(44)
        _ISDN_area = HSpacing(54)
      end
      contents = Top(
        VBox(
          VSpacing(1.5),
          _ISDN_card,
          VSpacing(0.2),
          ReplacePoint(Id(:DrvRpl), _ISDN_driver),
          VSpacing(1.5),
          HBox(
            HWeight(44, _ISDN_protocol),
            HSpacing(2),
            HWeight(54, _ISDN_area)
          ),
          VSpacing(1.5),
          # STARTMODE
          Left(Ops.get_term(widgets, [1, "widget"], Empty())),
          VSpacing(1.5)
        )
      )

      # DIALOG PREPARE
      Wizard.SetContentsButtons(
        caption,
        contents,
        helptext,
        Label.BackButton,
        Label.OKButton
      )

      if Ops.greater_or_equal(1, Builtins.size(_DrvList))
        UI.ChangeWidget(Id(:DrvBox), :Enabled, false)
      end

      UI.ChangeWidget(
        Id(:CCode),
        :Enabled,
        !Builtins.haskey(_CountryCodes, ccode)
      )

      if !ISDN.only_dsl
        EnableProtocols(Ops.get_map(_CardDrivers, _CurrentDrvIndex, {}))
      end

      # Special Handling AVM T1
      UI.ChangeWidget(Id(:t1b), :Value, t1b) if _Default_TYPE == 8005
      UI.ChangeWidget(Id("STARTMODE"), :Value, startmode)

      # MAIN CYCLE
      ret = nil
      while true
        ret = UI.UserInput

        # abort?
        if ret == :abort || ret == :cancel
          break if Popup.ReallyAbort(true)
          next
        elsif ret == :DrvBox
          id = Builtins.tointeger(UI.QueryWidget(Id(:DrvBox), :Value))
          if id != _CurrentDrvIndex
            desc = Ops.get_string(_CardDrivers, [id, "description"], "")
            desc = Ops.get_string(drvdesc, desc, desc) if desc != ""
            _CurrentDrvIndex = id
            UI.ChangeWidget(Id(:DrvDesc), :Value, desc)
            EnableProtocols(Ops.get_map(_CardDrivers, _CurrentDrvIndex, {}))
          end
        elsif ret == :Country
          newcc = Convert.to_string(UI.QueryWidget(Id(:Country), :Value))
          next if newcc == ccode
          if Builtins.haskey(_CountryCodes, newcc)
            ccode = newcc
            UI.ChangeWidget(Id(:CCode), :Enabled, false)
          else
            ccode = ""
            UI.ChangeWidget(Id(:CCode), :Enabled, true)
            UI.ChangeWidget(Id(:ilog), :Value, false)
          end
          UI.ChangeWidget(Id(:CCode), :Value, ccode)
        elsif ret == :back
          break
        elsif ret == :next
          if ISDN.only_dsl
            isdnlog = false
          else
            protocol = Convert.to_string(
              UI.QueryWidget(Id(:protocol), :CurrentButton)
            )
            ccode = Convert.to_string(UI.QueryWidget(Id(:CCode), :Value))
            areacode = Convert.to_string(UI.QueryWidget(Id(:areacode), :Value))
            dialprefix = Convert.to_string(
              UI.QueryWidget(Id(:dialprefix), :Value)
            )
            isdnlog = Convert.to_boolean(UI.QueryWidget(Id(:ilog), :Value))

            val = nil

            if UI.WidgetExists(Id(:IOADR))
              val = Convert.to_string(UI.QueryWidget(Id(:IOADR), :Value))
              Ops.set(ISDN.hw_device, "PARA_IO", val)
            end
            if UI.WidgetExists(Id(:IRQ))
              val = Convert.to_string(UI.QueryWidget(Id(:IRQ), :Value))
              Ops.set(ISDN.hw_device, "PARA_IRQ", val)
            end
            if UI.WidgetExists(Id(:MEMBASE))
              val = Convert.to_string(UI.QueryWidget(Id(:MEMBASE), :Value))
              Ops.set(ISDN.hw_device, "PARA_MEMBASE", val)
            end
          end

          Builtins.y2debug("proto: %1", protocol)

          if Ops.greater_than(_DriverCnt, 1)
            _CurrentDrvIndex = Convert.to_integer(
              UI.QueryWidget(Id(:DrvBox), :Value)
            )
          end
          Ops.set(cur_card, "sel_drv", _CurrentDrvIndex)
          _Default_TYPE = get_i4ltype(cur_card)
          _Default_SUBTYPE = get_i4lsubtype(cur_card)
          # Special Handling AVM T1
          if _Default_TYPE == 8005
            if Convert.to_boolean(UI.QueryWidget(Id(:t1b), :Value))
              _Default_SUBTYPE = Ops.add(_Default_SUBTYPE, 1)
            end
          end
          ISDN.hw_device = Builtins.union(
            ISDN.hw_device,
            {
              "PARA_TYPE"     => Builtins.sformat("%1", _Default_TYPE),
              "PARA_SUBTYPE"  => Builtins.sformat("%1", _Default_SUBTYPE),
              "NAME"          => Builtins.sformat(
                "%1",
                Ops.get_string(cur_card, "longname", "unknown")
              ),
              "DRIVER"        => Builtins.sformat(
                "%1",
                Ops.get_string(
                  _CardDrivers,
                  [_CurrentDrvIndex, "mod_name"],
                  "unknown"
                )
              ),
              "STARTMODE"     => UI.QueryWidget(Id("STARTMODE"), :Value),
              "PROTOCOL"      => protocol,
              "AREACODE"      => Ops.add(Ops.add(ccode, " "), areacode),
              "DIALPREFIX"    => dialprefix,
              "ISDNLOG_START" => isdnlog ? "yes" : "no"
            }
          )
          # check and maybe install missing packages
          pkgs = []

          pkgs = Ops.get_list(_CardDrivers, [_CurrentDrvIndex, "need_pkg"], [])
          if pkgs != nil && pkgs != [] && !isdnlog
            pkgs = Builtins.filter(
              Convert.convert(pkgs, :from => "list", :to => "list <string>")
            ) { |p| p != "i4l-isdnlog" }
          end
          if pkgs == [""]
            Builtins.y2warning(
              "no package list for %1",
              Ops.get_string(cur_card, "longname", "unknown")
            )
          else
            ISDN.installpackages = Builtins.merge(ISDN.installpackages, pkgs)
          end

          features = Ops.get_list(
            _CardDrivers,
            [_CurrentDrvIndex, "features"],
            []
          )
          # if it is a DSL capable card
          if Builtins.contains(features, "DSL")
            ISDN.have_dsl = true
            # only one time needed
            ISDN.DRDSLrun = true
          else
            ISDN.have_dsl = false
          end
          if Builtins.contains(features, "DSLONLY")
            ISDN.have_dsl = true
            # only one time needed
            ISDN.DRDSLrun = true
            ISDN.only_dsl = true
          else
            ISDN.only_dsl = false
          end

          if _Default_TYPE == 8002 || _Default_TYPE == 8003 ||
              _Default_TYPE == 8004
            # multiline Popup::YesNo text
            if !Popup.YesNo(
                _(
                  " WARNING\n" +
                    "\n" +
                    "You have selected a binary-only driver that is not\n" +
                    "part of our distribution. You can only use this driver\n" +
                    "after installing additional packages from AVM manually.\n" +
                    "\n" +
                    "Continue?\n"
                )
              )
              next
            end
          end
          break
        else
          Builtins.y2error("unexpected retcode: %1", ret)
          next
        end
      end
      deep_copy(ret)
    end
  end
end
