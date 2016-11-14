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
# File:	include/network/routines.ycp
# Package:	Network configuration
# Summary:	Miscellaneous routines
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkRoutinesInclude
    include I18n
    include Yast
    include Logger

    def initialize_network_routines(_include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "Call"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "String"
      Yast.import "NetworkService"
      Yast.import "PackageSystem"
      Yast.import "NetworkInterfaces"
      Yast.import "Arch"
      Yast.import "Confirm"
      Yast.import "Map"
      Yast.import "Netmask"
      Yast.import "Mode"
      Yast.import "IP"
      Yast.import "TypeRepository"
      Yast.import "Stage"
    end

    # Abort function
    # @return blah blah lahjk
    def Abort
      return false if Mode.commandline

      UI.PollInput == :abort
    end

    # Check for pending Abort press
    # @return true if pending abort
    def PollAbort
      UI.PollInput == :abort
    end

    # If modified, ask for confirmation
    # @return true if abort is confirmed
    def ReallyAbort
      Popup.ReallyAbort(true)
    end

    # If modified, ask for confirmation
    # @param [Boolean] modified true if modified
    # @return true if abort is confirmed
    def ReallyAbortCond(modified)
      !modified || Popup.ReallyAbort(true)
    end

    # Progress::NextStage and Progress::Title combined into one function
    # @param [String] title progressbar title
    def ProgressNextStage(title)
      Progress.NextStage
      Progress.Title(title)

      nil
    end

    # Change UI widget only if it exists
    # @param [Yast::Term] id widget id
    # @param [Symbol] param widget parameter
    # @param [Object] value widget parameter value
    def ChangeWidgetIfExists(id, param, value)
      id = deep_copy(id)
      value = deep_copy(value)
      if UI.WidgetExists(id)
        UI.ChangeWidget(id, param, value)
      else
        Builtins.y2debug("Not changing: %1", id)
      end

      nil
    end

    # Query UI widget only if it exists
    # @param [Yast::Term] id widget id
    # @param [Symbol] param widget parameter
    # @param [Object] value previous parameter value
    # @return widget value if exists, previous value otherwise
    def QueryWidgetIfExists(id, param, value)
      id = deep_copy(id)
      value = deep_copy(value)
      return UI.QueryWidget(id, param) if UI.WidgetExists(id)
      Builtins.y2debug("Not changing: %1", id)
      deep_copy(value)
    end

    # Check if required packages are installed and install them if they're not
    # @param [Array<String>] packages list of required packages (["rpm", "bash"])
    # @return `next if packages installation is successfull, `abort otherwise
    def PackagesInstall(packages)
      packages = deep_copy(packages)
      return :next if packages == []

      log.info "Checking packages: #{packages}"

      # bnc#888130 In inst-sys, there is no RPM database to check
      # If the required package is part of the inst-sys, it will work,
      # if not, package can't be installed anyway
      #
      # Ideas:
      # - check /.packages.* for presence of the required package
      # - use `extend` to load the required packages on-the-fly
      return :next if Stage.initial

      Yast.import "Package"
      return :next if Package.InstalledAll(packages)

      # Popup text
      text = _("These packages need to be installed:") + "<p>"
      Builtins.foreach(packages) do |l|
        text = Ops.add(text, Builtins.sformat("%1<br>", l))
      end
      Builtins.y2debug("Installing packages: %1", text)

      ret = false
      loop do
        ret = Package.InstallAll(packages)
        break if ret == true

        if ret == false && Package.InstalledAll(packages)
          ret = true
          break
        end

        # Popup text
        if !Popup.YesNo(
          _(
            "The required packages are not installed.\n" \
              "The configuration will be aborted.\n" \
              "\n" \
              "Try again?\n"
          ) + "\n"
          )
          break
        end
      end

      ret == true ? :next : :abort
    end

    # Create comment for changed file
    # @param [String] modul YaST2 module changing the file
    # @return comment
    # @example ChangedComment("lan") -> # Changed by YaST2 module lan 1.1.2000"
    def ChangedComment(modul)
      ret = "\n# Changed by YaST2"
      if !modul.nil? && modul != ""
        ret = Ops.add(Ops.add(ret, " module "), modul)
      end
      out = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "/bin/date '+%x'")
      )
      date = Ops.get_string(out, "stdout", "")
      ret = Ops.add(Ops.add(ret, " "), date) if date != ""
      ret
    end

    # Show busy popup (for proposal)
    # @param [String] message label to be shown
    def BusyPopup(message)
      UI.BusyCursor
      UI.OpenDialog(VBox(Label(message)))

      nil
    end

    # Close busy popup
    # @see #BusyPopup
    def BusyPopupClose
      UI.CloseDialog

      nil
    end

    # Checks if given value is emtpy.
    def IsEmpty(value)
      value = deep_copy(value)
      TypeRepository.IsEmpty(value)
    end

    # Checks if given value is non emtpy.
    def IsNotEmpty(value)
      value = deep_copy(value)
      !IsEmpty(value)
    end

    # Create a list of items for UI from the given list
    # @param [Array] l given list for conversion
    # @param [Fixnum] selected selected item (0 for the first)
    # @return a list of items
    # @example [ "x", "y" ] -&gt; [ `item(`id(0), "x"), `item(`id(1), "y") ]
    def list2items(l, selected)
      l = deep_copy(l)
      items = []
      n = 0
      Builtins.foreach(l) do |i|
        items = Builtins.add(items, Item(Id(n), i, n == selected))
        n = Ops.add(n, 1)
      end
      deep_copy(items)
    end

    # Create a list of items for UI from the given hardware list.
    #
    # This list is used when selecting <ol>
    # <li> detected unconfigured cards,
    # there we want to see the link status </li>
    # <li> undetected cards manually. there is no link status there
    # and it won't be displayed. all is ok. </li>
    # </ol>
    # @param [Array<Hash>] l given list for conversion
    # @param [Fixnum] selected selected item (0 for the first)
    # @return a list of items
    def hwlist2items(l, selected)
      l = deep_copy(l)
      items = []
      n = 0
      Builtins.foreach(l) do |i|
        # Table field (Unknown device)
        hwname = Ops.get_locale(i, "name", _("Unknown"))
        num = Ops.get_integer(i, "num", n) # num for detected, n for manual
        items = Builtins.add(items, Item(Id(num), hwname, num == selected))
        n = Ops.add(n, 1)
      end
      deep_copy(items)
      # return list2items(maplist(map h, l, { return h["name"]:_("Unknown Device"); }), selected);
    end

    # Display the finished popup and possibly run another module.
    # If not modified, don't do anything.
    # @param [Boolean] modified true if there are any modified data
    # @param [String] head headline to be shown
    # @param [String] text text to be shown
    # @param [String] run module to be run
    # @param [Array] params parameters to pass to the module
    # @return always `next
    def FinishPopup(modified, head, text, run, params)
      params = deep_copy(params)
      return :next if !modified

      h = head
      if h.nil? || h == ""
        # Popup headline
        h = _("Configuration Successfully Saved")
      end

      heads = {
        # Popup headline
        "dns"      => _("DNS Configuration Successfully Saved"),
        # Popup headline
        "dsl"      => _("DSL Configuration Successfully Saved"),
        # Popup headline
        "host"     => _(
          "Hosts Configuration Successfully Saved"
        ),
        # Popup headline
        "isdn"     => _(
          "ISDN Configuration Successfully Saved"
        ),
        # Popup headline
        "lan"      => _(
          "Network Card Configuration Successfully Saved"
        ),
        # Popup headline
        "modem"    => _(
          "Modem Configuration Successfully Saved"
        ),
        # Popup headline
        "proxy"    => _(
          "Proxy Configuration Successfully Saved"
        ),
        # Popup headline
        "provider" => _(
          "Provider Configuration Successfully Saved"
        ),
        # Popup headline
        "routing"  => _(
          "Routing Configuration Successfully Saved"
        )
      }
      h = Ops.get_string(heads, head, h)

      t = text
      texts = {
        # Popup text
        "mail" => _("Configure mail now?")
      }
      t = Ops.get_string(texts, run, text) if t == ""
      if t == ""
        # Popup text
        t = Builtins.sformat(_("Run configuration of %1?"), run)
      end

      if run != ""
        ret = Popup.YesNoHeadline(h, t)
        # FIXME: check for the module presence
        Call.Function(run, params) if ret == true
      else
        Popup.AnyMessage(h, t)
      end

      :next
    end

    # For s390 hwinfo gives us a multitude of types but some are handled
    # the same, mostly acording to the driver which is used. So let's group
    # them under the name Driver Type.
    # @param [String] type a type, as in Lan::type
    # @return driver type, like formerly type2 for s390
    def DriverType(type)
      drvtype = type
      # handle HSI like qeth, S#40692#c15
      if type == "hsi"
        drvtype = "qeth"
      # Should eth occur on s390?
      elsif type == "tr" || type == "eth"
        drvtype = "lcs"
      # N#82891
      elsif type == "escon" || type == "ficon"
        drvtype = "ctc"
      end
      drvtype
    end

    def needHwcfg(hw)
      hw = deep_copy(hw)
      need = true
      # if kernel will autoload module for device
      if IsNotEmpty(Ops.get_string(hw, "modalias", ""))
        if Ops.greater_than(Builtins.size(Ops.get_list(hw, "drivers", [])), 1)
          Builtins.y2milestone(
            "there are more modules available for device, hwcfg is needed"
          )
        else
          Builtins.y2milestone(
            "Just one autoloadable module available.No need to write hwcfg"
          )
          need = false
        end
      # not autoload because of built-in driver (compiled in kernel)
      elsif IsEmpty(Ops.get_string(hw, "driver_module", ""))
        Builtins.y2milestone(
          "built-in driver %1",
          Ops.get_string(hw, "driver", "")
        )
        need = false
      end
      need
    end

    def dev_name_to_sysfs_id(dev_name, hardware)
      hardware = deep_copy(hardware)
      # hardware is cached list of netcards
      hw_item = Builtins.find(hardware) do |i|
        Ops.get_string(i, "dev_name", "") == dev_name
      end
      Ops.get_string(hw_item, "sysfs_id", "")
    end

    def sysfs_card_type(sysfs_id, _hardware)
      return "none" if sysfs_id == ""
      filename = Ops.add(Ops.add("/sys", sysfs_id), "/card_type")
      card_type = Convert.to_string(SCR.Read(path(".target.string"), filename))
      String.FirstChunk(card_type, "\n")
    end

    def s390_device_needs_persistent_mac(sysfs_id, hardware)
      hardware = deep_copy(hardware)
      card_type = sysfs_card_type(sysfs_id, hardware)
      types_needing_persistent = [
        "OSD_100",
        "OSD_1000",
        "OSD_10GIG",
        "OSD_FE_LANE",
        "OSD_GbE_LANE",
        "OSD_Express"
      ]
      needs_persistent = Builtins.contains(types_needing_persistent, card_type)
      Builtins.y2milestone(
        "Sysfs Device: %1, card type: %2, needs persistent MAC: %3",
        sysfs_id,
        card_type,
        needs_persistent
      )
      needs_persistent
    end

    # map<string, any> getcfg(string options, string device){
    #  map <string, any> cfg=$[];
    #  map <string, any> output = (map <string, any>)SCR::Execute(.target.bash_output,
    # 		sformat("getcfg %1 %2", options, device));
    #   foreach(string row, splitstring(output["stdout"]:"", "\n"), {
    #    row=deletechars(row, "\\\"\;");
    #    list<string> keyval=splitstring(row, "=");
    #    if (size(keyval)>1) cfg[keyval[0]:""]=keyval[1]:"";
    #
    #   });
    #  y2milestone("%1 %2\n%3", options, device, cfg);
    #  return cfg;
    # }

    def getHardware(sysfs_id, hw)
      hardware = {}
      Builtins.foreach(hw) do |hw_temp|
        if sysfs_id ==
            Builtins.sformat("/sys%1", Ops.get_string(hw_temp, "sysfs_id", ""))
          hardware = deep_copy(hw_temp)
        end
      end
      deep_copy(hardware)
    end

    def DistinguishedName(name, hwdevice)
      hwdevice = deep_copy(hwdevice)
      if Ops.get_string(hwdevice, "sysfs_bus_id", "") != ""
        return Builtins.sformat(
          "%1 (%2)",
          name,
          Ops.get_string(hwdevice, "sysfs_bus_id", "")
        )
      end
      name
    end

    # Extract the device 'name'
    # @param [Hash] hwdevice hardware device
    # @return name consisting of vendor and device name
    def DeviceName(hwdevice)
      hwdevice = deep_copy(hwdevice)
      delimiter = " " # "\n"; #FIXME: constant

      if IsNotEmpty(Ops.get_string(hwdevice, "device", ""))
        return Ops.get_string(hwdevice, "device", "")
      end

      model = Ops.get_string(hwdevice, "model", "")
      return model if model != "" && !model.nil?

      vendor = Ops.get_string(hwdevice, "sub_vendor", "")
      dev = Ops.get_string(hwdevice, "sub_device", "")

      if vendor == "" || dev == ""
        vendor = Ops.get_string(hwdevice, "vendor", "")
        dev = Ops.get_string(hwdevice, "device", "")
      end

      if vendor != ""
        return Ops.add(Ops.add(vendor, delimiter), dev)
      else
        return dev
      end
    end

    # Validates given name for use as a nic name in sysconfig. See bnc#784952
    def ValidNicName(name)
      # 16 is the kernel limit on interface name size (IFNAMSIZ)
      return false if !Builtins.regexpmatch(name, "^[[:alnum:]._:-]{1,15}$")

      true
    end

    # Checks if device with the given name is configured already.
    def UsedNicName(name)
      Builtins.contains(NetworkInterfaces.List(""), name)
    end

    # Simple convertor from subclass to controller type.
    # @param [Hash] hwdevice map with card info containing "subclass"
    # @return short device name
    # @example ControllerType(<ethernet controller map>) -> "eth"
    def ControllerType(hwdevice)
      hwdevice = deep_copy(hwdevice)
      return "modem" if Ops.get_string(hwdevice, "subclass", "") == "Modem"
      return "isdn" if Ops.get_string(hwdevice, "subclass", "") == "ISDN"
      return "dsl" if Ops.get_string(hwdevice, "subclass", "") == "DSL"

      subclass_id = Ops.get_integer(hwdevice, "sub_class_id", -1)

      # Network controller
      if Ops.get_integer(hwdevice, "class_id", -1) == 2
        if subclass_id == 0
          return "eth"
        elsif subclass_id == 1
          return "tr"
        elsif subclass_id == 2
          return "fddi"
        elsif subclass_id == 3
          return "atm"
        elsif subclass_id == 4
          return "isdn"
        elsif subclass_id == 6 ## Should be PICMG?
          return "ib"
        elsif subclass_id == 7
          return "ib"
        elsif subclass_id == 129
          return "myri"
        elsif subclass_id == 130
          return "wlan"
        elsif subclass_id == 131
          return "xp"
        elsif subclass_id == 134
          return "qeth"
        elsif subclass_id == 135
          return "hsi"
        elsif subclass_id == 136
          return "ctc"
        elsif subclass_id == 137
          return "lcs"
        elsif subclass_id == 142
          return "ficon"
        elsif subclass_id == 143
          return "escon"
        elsif subclass_id == 144
          return "iucv"
        elsif subclass_id == 145
          return "usb" # #22739
        elsif subclass_id == 128
          # Nothing was found
          Builtins.y2error("Unknown network controller type: %1", hwdevice)
          Builtins.y2error(
            "It's probably missing in hwinfo (NOT src/hd/hd.h:sc_net_if)"
          )
          return ""
        else
          # Nothing was found
          Builtins.y2error("Unknown network controller type: %1", hwdevice)
          return ""
        end
      end
      # exception for infiniband device
      if Ops.get_integer(hwdevice, "class_id", -1) == 12
        return "ib" if subclass_id == 6
      end

      # Communication controller
      if Ops.get_integer(hwdevice, "class_id", -1) == 7
        if subclass_id == 3
          return "modem"
        elsif subclass_id == 128
          # Nothing was found
          Builtins.y2error("Unknown network controller type: %1", hwdevice)
          Builtins.y2error(
            "It's probably missing in hwinfo (src/hd/hd.h:sc_net_if)"
          )
          return ""
        else
          # Nothing was found
          Builtins.y2error("Unknown network controller type: %1", hwdevice)
          return ""
        end
      # Network Interface
      # check the CVS history and then kill this code!
      # 0x107 is the output of hwinfo --network
      # which lists the INTERFACES
      # but we are inteested in hwinfo --netcard
      # Just make sure that hwinfo or ag_probe
      # indeed does not pass this to us
      elsif Ops.get_integer(hwdevice, "class_id", -1) == 263
        Builtins.y2milestone("CLASS 0x107") # this should happen rarely
        if subclass_id == 0
          return "lo"
        elsif subclass_id == 1
          return "eth"
        elsif subclass_id == 2
          return "tr"
        elsif subclass_id == 3
          return "fddi"
        elsif subclass_id == 4
          return "ctc"
        elsif subclass_id == 5
          return "iucv"
        elsif subclass_id == 6
          return "hsi"
        elsif subclass_id == 7
          return "qeth"
        elsif subclass_id == 8
          return "escon"
        elsif subclass_id == 9
          return "myri"
        elsif subclass_id == 10
          return "wlan"
        elsif subclass_id == 11
          return "xp"
        elsif subclass_id == 12
          return "usb"
        elsif subclass_id == 128
          # Nothing was found
          Builtins.y2error("Unknown network interface type: %1", hwdevice)
          Builtins.y2error(
            "It's probably missing in hwinfo (src/hd/hd.h:sc_net_if)"
          )
          return ""
        elsif subclass_id == 129
          return "sit"
        else
          # Nothing was found
          Builtins.y2error("Unknown network interface type: %1", hwdevice)
          return ""
        end
      elsif Ops.get_integer(hwdevice, "class_id", -1) == 258
        return "modem"
      elsif Ops.get_integer(hwdevice, "class_id", -1) == 259
        return "isdn"
      elsif Ops.get_integer(hwdevice, "class_id", -1) == 276
        return "dsl"
      end

      # Nothing was found
      Builtins.y2error("Unknown controller type: %1", hwdevice)
      ""
    end

    # Read HW information
    # @param [String] hwtype type of devices to read (netcard|modem|isdn)
    # @return array of hashes describing detected device
    def ReadHardware(hwtype)
      hardware = []

      Builtins.y2debug("hwtype=%1", hwtype)

      # Confirmation: label text (detecting hardware: xxx)
      return [] if !confirmed_detection(hwtype)

      # read the corresponding hardware
      allcards = []
      if hwtypes[hwtype]
        allcards = Convert.to_list(SCR.Read(hwtypes[hwtype]))
      elsif hwtype == "all" || hwtype.nil? || hwtype.empty?
        Builtins.maplist(
          Convert.convert(
            Map.Values(hwtypes),
            from: "list",
            to:   "list <path>"
          )
        ) do |v|
          allcards = Builtins.merge(allcards, Convert.to_list(SCR.Read(v)))
        end
      else
        Builtins.y2error("unknown hwtype: %1", hwtype)
        return []
      end

      if allcards.nil?
        Builtins.y2error("hardware detection failure")
        return []
      end

      # #97540
      bms = Convert.to_string(SCR.Read(path(".etc.install_inf.BrokenModules")))
      bms = "" if bms.nil?
      broken_modules = Builtins.splitstring(bms, " ")

      # fill in the hardware data
      num = 0
      Builtins.maplist(
        Convert.convert(allcards, from: "list", to: "list <map>")
      ) do |card|
        # common stuff
        resource = Ops.get_map(card, "resource", {})
        controller = ControllerType(card)

        one = {}
        one["name"] = DeviceName(card)
        # Temporary solution for s390: #40587
        one["name"] = DistinguishedName(one["name"], card) if Arch.s390
        one["type"] = controller
        one["udi"] = card["udi"] || ""
        one["sysfs_id"] = card["sysfs_id"] || ""
        one["dev_name"] = card["dev_name"] || ""
        one["requires"] = card["requires"] || []
        one["modalias"] = card["modalias"] || ""
        one["unique"] = card["unique_key"] || ""
        # driver option needs for (bnc#412248)
        one["driver"] = card["driver"] || ""
        # Each card remembers its position in the list of _all_ cards.
        # It is used when selecting the card from the list of _unconfigured_
        # ones (which may be smaller). #102945.
        one["num"] = num

        case controller
          # modem
          when "modem"
            one["device_name"] = card["dev_name"] || ""
            one["drivers"] = card["drivers"] || []

            speed = Ops.get_integer(resource, ["baud", 0, "speed"], 57_600)
            # :-) have to check .probe and libhd if this confusion is
            # really necessary. maybe a pppd bug too? #148893
            speed = 57_600 if speed == 12_000_000

            one["speed"] = speed
            one["init1"] = Ops.get_string(resource, ["init_strings", 0, "init1"], "")
            one["init2"] = Ops.get_string(resource, ["init_strings", 0, "init2"], "")
            one["pppd_options"] = Ops.get_string(resource, ["pppd_option", 0, "option"], "")

          # isdn card
          when "isdn"
            drivers = card["isdn"] || []
            one["drivers"] = drivers
            one["sel_drv"] = 0
            one["bus"] = card["bus"] || ""
            one["io"] = Ops.get_integer(resource, ["io", 0, "start"], 0)
            one["irq"] = Ops.get_integer(resource, ["irq", 0, "irq"], 0)

          # dsl card
          when "dsl"
            driver_info = Ops.get_map(card, ["dsl", 0], {})
            translate_mode = { "capiadsl" => "capi-adsl", "pppoe" => "pppoe" }
            m = driver_info["mode"] || ""
            one["pppmode"] = translate_mode[m] || m

          # treat the rest as a network card
          else
            # drivers:
            # Although normally there is only one module
            # (one=$[active:, module:, options:,...]), the generic
            # situation is: one or more driver variants (exclusive),
            # each having one or more modules (one[drivers])

            # only drivers that are not marked as broken (#97540)
            drivers = Builtins.filter(Ops.get_list(card, "drivers", [])) do |d|
              # ignoring more modules per driver...
              module0 = Ops.get_list(d, ["modules", 0], []) # [module, options]
              brk = broken_modules.include?(module0[0])

              if brk
                Builtins.y2milestone("In BrokenModules, skipping: %1", module0)
              end

              !brk
            end

            if drivers == []
              Builtins.y2milestone("No good drivers found")
            else
              one["drivers"] = drivers

              driver = drivers[0] || {}
              one["active"] = driver["active"] || false
              module0 = Ops.get_list(driver, ["modules", 0], [])
              one["module"] = module0[0] || ""
              one["options"] = module0[1] || ""
            end

            # FIXME: this should be also done for modems and others
            # FIXME: #13571
            hp = card["hotplug"] || ""
            if hp == "pcmcia" || hp == "cardbus"
              one["hotplug"] = "pcmcia"
            elsif hp == "usb"
              one["hotplug"] = "usb"
            end

            # store the BUS type
            bus = card["bus_hwcfg"] || card["bus"] || ""

            if bus == "PCI"
              bus = "pci"
            elsif bus == "USB"
              bus = "usb"
            elsif bus == "Virtual IO"
              bus = "vio"
            end

            one["bus"] = bus
            one["busid"] = card["sysfs_bus_id"] || ""
            one["mac"] = Ops.get_string(resource, ["hwaddr", 0, "addr"], "")
            # is the cable plugged in? nil = don't know
            one["link"] = Ops.get(resource, ["link", 0, "state"])

            # Wireless Card Features
            one["wl_channels"] = Ops.get(resource, ["wlan", 0, "channels"])
            one["wl_bitrates"] = Ops.get(resource, ["wlan", 0, "bitrates"])
            one["wl_auth_modes"] = Ops.get(resource, ["wlan", 0, "auth_modes"])
            one["wl_enc_modes"] = Ops.get(resource, ["wlan", 0, "enc_modes"])
          end

        if controller != "" && !filter_out(card, one["module"])
          Builtins.y2debug("found device: %1", one)

          Ops.set(hardware, Builtins.size(hardware), one)
          num += 1
        else
          Builtins.y2milestone("Filtering out: %1", card)
        end
      end

      # if there is wlan, put it to the front of the list
      # that's because we want it proposed and currently only one card
      # can be proposed
      found = false
      i = 0
      Builtins.foreach(hardware) do |h|
        if h["type"] == "wlan"
          found = true
          raise Break
        end
        i += 1
      end

      if found
        temp = hardware[0] || {}
        hardware[0] = hardware[i]
        hardware[i] = temp
        # adjust mapping: #98852, #102945
        Ops.set(hardware, [0, "num"], 0)
        Ops.set(hardware, [i, "num"], i)
      end

      Builtins.y2debug("Hardware=%1", hardware)
      deep_copy(hardware)
    end

    # TODO: begin:
    # Following functions should be generalized and ported into yast-yast2

    # @param Shell command to run
    # @return Hash in form $[ "exit": <command-exit-status>, "output": [ <1st line>, <2nd line>, ... ] ]
    def RunAndRead(command)
      ret = { "exit" => false, "output" => [] }
      result = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      output = Ops.get_string(result, "stdout", "")

      if Builtins.regexpmatch(output, ".*\n$")
        output = Builtins.substring(
          output,
          0,
          Ops.subtract(Builtins.size(output), 1)
        )
      end

      Ops.set(ret, "output", Builtins.splitstring(output, "\n"))
      Ops.set(ret, "exit", Ops.get_integer(result, "exit", 1) == 0)

      if Ops.get_boolean(ret, "exit", false) == false ||
          IsEmpty(Ops.get_string(result, "stderr", "")) == false
        Builtins.y2error(
          "RunAndRead <%1>: Command execution failed.\n%2",
          command,
          Ops.get_string(result, "stderr", "")
        )
      end

      deep_copy(ret)
    end

    # @param Shell command to run
    # @return whether command execution succeeds
    def Run(command)
      ret = SCR.Execute(path(".target.bash"), command) == 0

      Builtins.y2error("Run <%1>: Command execution failed.", command) if !ret

      ret
    end
    # TODO: end

    # Return list of all interfaces present in the system (not only configured ones as NetworkInterfaces::List does).
    #
    # @return [Array] of interface names.
    def GetAllInterfaces
      result = RunAndRead("ls /sys/class/net")

      if Ops.get_boolean(result, "exit", false)
        Ops.get_list(result, "output", [])
      else
        []
      end
    end

    def SetLinkUp(dev_name)
      log.info("Setting link up for interface #{dev_name}")
      Run("ip link set #{dev_name} up")
    end

    def SetLinkDown(dev_name)
      log.info("Setting link down for interface #{dev_name}")
      Run("ip link set #{dev_name} down")
    end

    # Tries to set all available interfaces up
    #
    # @return [boolean] false if some of interfaces cannot be set up
    def SetAllLinksUp
      interfaces = GetAllInterfaces()

      return false if interfaces.empty?

      interfaces.all? { |i| SetLinkUp(i) }
    end

    # Tries to set all available interfaces down
    #
    # @return [boolean] false if some of interfaces cannot be set down
    def SetAllLinksDown
      interfaces = GetAllInterfaces()

      return false if interfaces.empty?

      interfaces.all? { |i| SetLinkDown(i) }
    end

    # Checks if given device has carrier
    #
    # @return [boolean] true if device has carrier
    def has_carrier?(dev_name)
      SCR.Read(
        path(".target.string"),
        "/sys/class/net/#{dev_name}/carrier"
      ).to_i != 0
    end

    # With NPAR and SR-IOV capabilities, one device could divide a ethernet
    # port in various. If the driver module support it, we can check the phys
    # port id via sysfs reading the /sys/class/net/$dev_name/phys_port_id
    #
    # @param [String] device name to check
    # @return [String] physical port id if supported or a empty string if not
    def physical_port_id(dev_name)
      SCR.Read(
        path(".target.string"),
        "/sys/class/net/#{dev_name}/phys_port_id"
      ).to_s.strip
    end

    # @return [boolean] true if the physical port id is not empty
    # @see #physical_port_id
    def physical_port_id?(dev_name)
      !physical_port_id(dev_name).empty?
    end

    # Dev port of of the given interface from /sys/class/net/$dev_name/dev_port
    #
    # @param [String] device name to check
    # @return [String] dev port or an empty string if not
    def dev_port(dev_name)
      SCR.Read(
        path(".target.string"),
        "/sys/class/net/#{dev_name}/dev_port"
      ).to_s.strip
    end

    # Checks if the given interface exports its dev port via sysfs
    #
    # @return [boolean] true if the dev port is not empty
    # @see #physical_port_id
    def dev_port?(dev_name)
      !dev_port(dev_name).empty?
    end

    # Checks if device is physically connected to a network
    #
    # It does neccessary steps which might be needed for proper initialization
    # of devices driver.
    #
    # @return [boolean] true if physical layer is connected
    def phy_connected?(dev_name)
      return true if has_carrier?(dev_name)

      # SetLinkUp ensures that driver is loaded
      SetLinkUp(dev_name)

      # Wait for driver initialization if needed. bnc#876848
      # 5 secs is minimum proposed by sysconfig guys for intel drivers.
      #
      # For a discussion regarding this see
      # https://github.com/yast/yast-network/pull/202
      sleep(5)

      has_carrier?(dev_name)
    end

    def validPrefixOrNetmask(ip, mask)
      valid_mask = false
      if Builtins.substring(mask, 0, 1) == "/"
        mask = Builtins.substring(mask, 1)
      end

      if IP.Check4(ip) && (Netmask.Check4(mask) || Netmask.CheckPrefix4(mask))
        valid_mask = true
      elsif IP.Check6(ip) && Netmask.Check6(mask)
        valid_mask = true
      else
        Builtins.y2warning("IP address %1 is not valid", ip)
      end
      valid_mask
    end

    def unconfigureable_service?
      return true if Mode.normal && NetworkService.is_network_manager
      return true if NetworkService.is_disabled

      false
    end

    # Disables all widgets which cannot be configured with current network service
    #
    # see bnc#433084
    # if listed any items, disable them, if show_popup, show warning popup
    #
    # returns true if items were disabled
    def disable_unconfigureable_items(items, show_popup)
      return false if !unconfigureable_service?

      items.each { |i| UI.ChangeWidget(Id(i), :Enabled, false) }

      if show_popup
        Popup.Warning(
          _(
            "Network is currently handled by NetworkManager\n" \
            "or completely disabled. YaST is unable to configure some options."
          )
        )
        UI.FakeUserInput("ID" => "global")
      end

      true
    end

  private

    # Checks if the device should be filtered out in ReadHardware
    def filter_out(device_info, driver)
      # filter out device with virtio_pci Driver and no Device File (bnc#585506)
      if driver == "virtio_pci" && (device_info["dev_name"] || "") == ""
        log.info("Filtering out virtio device without device file.")
        return true
      end

      # filter out device with chelsio Driver and no Device File or which cannot networking(bnc#711432)
      if driver == "cxgb4" &&
          (device_info["dev_name"] || "") == "" ||
          device_info["vendor_id"] == 70_693 &&
              device_info["device_id"] == 82_178
        log.info("Filtering out Chelsio device without device file.")
        return true
      end

      if device_info["device"] == "IUCV" && device_info["sysfs_bus_id"] != "netiucv"
        # exception to filter out uicv devices (bnc#585363)
        log.info("Filtering out iucv device different from netiucv.")
        return true
      end

      if device_info["storageonly"]
        # This is for broadcoms multifunctional devices. bnc#841170
        log.info("Filtering out device with storage only flag")
        return true
      end

      false
    end

    # Device type probe paths.
    def hwtypes
      {
        "netcard" => path(".probe.netcard"),
        "modem"   => path(".probe.modem"),
        "isdn"    => path(".probe.isdn"),
        "dsl"     => path(".probe.dsl")
      }
    end

    # If the user requested manual installation, ask whether to probe hardware of this type
    def confirmed_detection(hwtype)
      # Device type labels.
      hwstrings = {
        # Confirmation: label text (detecting hardware: xxx)
        "netcard" => _(
          "Network Cards"
        ),
        # Confirmation: label text (detecting hardware: xxx)
        "modem"   => _(
          "Modems"
        ),
        # Confirmation: label text (detecting hardware: xxx)
        "isdn"    => _(
          "ISDN Cards"
        ),
        # Confirmation: label text (detecting hardware: xxx)
        "dsl"     => _(
          "DSL Devices"
        )
      }

      hwstring = hwstrings[hwtype] || _("All Network Devices")
      Confirm.Detection(hwstring, nil)
    end
  end
end
