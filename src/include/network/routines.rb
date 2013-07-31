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
# File:	include/network/routines.ycp
# Package:	Network configuration
# Summary:	Miscellaneous routines
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkRoutinesInclude
    def initialize_network_routines(include_target)
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
    end

    # Abort function
    # @return blah blah lahjk
    def Abort
      Yast.import "Mode"
      return false if Mode.commandline
      return UI.PollInput == :abort

      # FIXME: NI
      # if(AbortFunction != nil)
      # 	return eval(AbortFunction) == true;
      false
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

      # FIXME: NI
      # return !Modified() || Popup::ReallyAbort(true);
    end

    # If modified, ask for confirmation
    # @param [Boolean] modified true if modified
    # @return true if abort is confirmed
    def ReallyAbortCond(modified)
      !modified || Popup.ReallyAbort(true) 

      # FIXME: NI
      # return (!modified && !Modified()) || Popup::ReallyAbort(true);
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
      Builtins.y2debug("Checking packages: %1", packages)

      Yast.import "Package"
      return :next if Package.InstalledAll(packages)

      # Popup text
      text = _("These packages need to be installed:") + "<p>"
      Builtins.foreach(packages) do |l|
        text = Ops.add(text, Builtins.sformat("%1<br>", l))
      end
      Builtins.y2debug("Installing packages: %1", text)

      ret = false
      while true
        ret = Package.InstallAll(packages)
        break if ret == true

        if ret == false && Package.InstalledAll(packages)
          ret = true
          break
        end

        # Popup text
        if !Popup.YesNo(
            _(
              "The required packages are not installed.\n" +
                "The configuration will be aborted.\n" +
                "\n" +
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
      if modul != nil && modul != ""
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
      # Translators: Appended after a network card name to indicate that
      # there is no carrier, no link to the network, the cable is not
      # plugged in. Preferably a short string.
      nolink = _("unplugged")

      items = []
      n = 0
      Builtins.foreach(l) do |i|
        # Table field (Unknown device)
        hwname = Ops.get_locale(i, "name", _("Unknown"))
        label = Ops.add(
          hwname,
          Ops.get(i, "link") == false ? Builtins.sformat(" (%1)", nolink) : ""
        )
        num = Ops.get_integer(i, "num", n) # num for detected, n for manual
        items = Builtins.add(items, Item(Id(num), hwname, num == selected))
        n = Ops.add(n, 1)
      end
      deep_copy(items) 
      #return list2items(maplist(map h, l, { return h["name"]:_("Unknown Device"); }), selected);
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
      if h == nil || h == ""
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

      ret = nil
      if run != ""
        ret = Popup.YesNoHeadline(h, t)
        # FIXME: check for the module presence
        Call.Function(run, params) if ret == true
      else
        ret = Popup.AnyMessage(h, t)
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

    def busid_to_sysfs_id(busid, hardware)
      hardware = deep_copy(hardware)
      # hardware is cached list of netcards
      hw_item = Builtins.find(hardware) do |i|
        Ops.get_string(i, "busid", "") == busid
      end
      Ops.get_string(hw_item, "sysfs_id", "")
    end

    def dev_name_to_sysfs_id(dev_name, hardware)
      hardware = deep_copy(hardware)
      # hardware is cached list of netcards
      hw_item = Builtins.find(hardware) do |i|
        Ops.get_string(i, "dev_name", "") == dev_name
      end
      Ops.get_string(hw_item, "sysfs_id", "")
    end

    def sysfs_card_type(sysfs_id, hardware)
      hardware = deep_copy(hardware)
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

    def getHardware(sysfs_id, _Hw)
      _Hw = deep_copy(_Hw)
      hardware = {}
      Builtins.foreach(_Hw) do |hw_temp|
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
      delimiter = " " # "\n";
      model = ""
      vendor = ""
      dev = ""

      if IsNotEmpty(Ops.get_string(hwdevice, "device", ""))
        return Ops.get_string(hwdevice, "device", "")
      end

      model = Ops.get_string(hwdevice, "model", "")
      return model if model != "" && model != nil

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

    # Checks if given nic name is used already.
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
        elsif subclass_id == 6
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
    # @return true if success
    def ReadHardware(hwtype)
      _Hardware = []

      Builtins.y2debug("hwtype=%1", hwtype)

      num = 0
      paths = []
      allcards = []

      hwtypes = {
        "netcard" => path(".probe.netcard"),
        "modem"   => path(".probe.modem"),
        "isdn"    => path(".probe.isdn"),
        "dsl"     => path(".probe.dsl")
      }

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

      # Confirmation: label text (detecting hardware: xxx)
      hwstring = _("All Network Devices")
      if Builtins.haskey(hwstrings, hwtype)
        hwstring = Ops.get(hwstrings, hwtype, "")
      end
      return [] if !Confirm.Detection(hwstring, "yast-lan")

      # read the corresponding hardware
      if Builtins.haskey(hwtypes, hwtype)
        allcards = Convert.to_list(SCR.Read(Ops.get(hwtypes, hwtype)))
      #allcards=[$["bus":"PCI", "bus_hwcfg":"pci", "bus_id":2, "class_id":2, "dev_name":"wlan0", "dev_names":["wlan0"], "device":"AR242x 802.11abg Wireless PCI Express Adapter", "device_id":65564, "driver":"ath5k_pci", "driver_module":"ath5k", "drivers":[$["active":true, "modprobe":true, "modules":[["ath5k", ""]]]], "modalias":"pci:v0000168Cd0000001Csv00001A3Bsd00001026bc02sc00i00", "model":"Atheros AR242x 802.11abg Wireless PCI Express Adapter", "old_unique_key":"eHlF.oTCoeEt5Tw6", "parent_unique_key":"qTvu.bQ30eTbcr+3", "resource":$["hwaddr":[$["addr":"00:22:43:37:55:c3"]], "irq":[$["count":0, "enabled":true, "irq":17]], "link":[$["state":true]], "mem":[$["active":true, "length":65536, "start":4227792896]], "wlan":[$["auth_modes":["open", "sharedkey", "wpa-psk", "wpa-eap"], "channels":["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"], "enc_modes":["WEP40", "WEP104", "TKIP", "CCMP"], "frequencies":["2.412", "2.417", "2.422", "2.427", "2.432", "2.437", "2.442", "2.447", "2.452", "2.457", "2.462"]]]], "rev":"1", "sub_class_id":130, "sub_device":"AR5007EG 802.11bg Wi-Fi mini PCI express card", "sub_device_id":69670, "sub_vendor_id":72251, "sysfs_bus_id":"0000:02:00.0", "sysfs_id":"/devices/pci0000:00/0000:00:1c.1/0000:02:00.0", "udi":"/org/freedesktop/Hal/devices/pci_168c_1c", "unique_key":"y9sn.oTCoeEt5Tw6", "vendor":"Atheros Communications Inc.", "vendor_id":71308, "wlan":true], $["bus":"PCI", "bus_hwcfg":"pci", "bus_id":1, "class_id":2, "dev_name":"eth0", "dev_names":["eth0"], "device":"L1 Gigabit EthernetAdapter", "device_id":69670, "driver":"ATL1E", "driver_module":"atl1e", "drivers":[$["active":true, "modprobe":true, "modules":[["atl1e", ""]]]], "modalias":"pci:v00001969d00001026sv00001043sd00008324bc02sc00i00", "model":"Attansic L1 Gigabit Ethernet Adapter", "old_unique_key":"BiAc.emcIbgAqn59", "parent_unique_key":"Z7uZ.f4r+Yl3RyX5", "resource":$["hwaddr":[$["addr":"00:23:54:3f:7c:c3"]], "io":[$["active":true, "length":128, "mode":"rw", "start":56320]], "irq":[$["count":74680, "enabled":true, "irq":220]], "link":[$["state":true]], "mem":[$["active":true, "length":262144, "start":4093378560]]], "rev":"176", "sub_class_id":0,"sub_device_id":99108, "sub_vendor":"ASUSTeK Computer Inc.", "sub_vendor_id":69699, "sysfs_bus_id":"0000:01:00.0","sysfs_id":"/devices/pci0000:00/0000:00:1c.3/0000:01:00.0", "udi":"/org/freedesktop/Hal/devices/pci_1969_1026", "unique_key":"rBUF.emcIbgAqn59", "vendor":"Attansic Technology Corp.", "vendor_id":72041]];
      elsif hwtype == "all" || hwtype == "" || hwtype == nil
        Builtins.maplist(
          Convert.convert(
            Map.Values(hwtypes),
            :from => "list",
            :to   => "list <path>"
          )
        ) do |v|
          allcards = Builtins.merge(allcards, Convert.to_list(SCR.Read(v)))
        end
      else
        Builtins.y2error("unknown hwtype: %1", hwtype)
        return []
      end

      if allcards == nil
        Builtins.y2error("hardware detection failure")
        allcards = []
      end


      # #97540
      bms = Convert.to_string(SCR.Read(path(".etc.install_inf.BrokenModules")))
      bms = "" if bms == nil
      broken_modules = Builtins.splitstring(bms, " ")

      # fill in the hardware data
      Builtins.maplist(
        Convert.convert(allcards, :from => "list", :to => "list <map>")
      ) do |card|
        one = {}
        # common stuff
        resource = Ops.get_map(card, "resource", {})
        controller = ControllerType(card)
        card_ok = controller != ""
        Ops.set(one, "name", DeviceName(card))
        Ops.set(one, "type", controller)
        Ops.set(one, "udi", Ops.get_string(card, "udi", ""))
        Ops.set(one, "sysfs_id", Ops.get_string(card, "sysfs_id", ""))
        Ops.set(one, "dev_name", Ops.get_string(card, "dev_name", ""))
        Ops.set(one, "requires", Ops.get_list(card, "requires", []))
        Ops.set(one, "modalias", Ops.get_string(card, "modalias", ""))
        Ops.set(one, "unique", Ops.get_string(card, "unique_key", ""))
        # driver option needs for (bnc#412248)
        Ops.set(one, "driver", Ops.get_string(card, "driver", ""))
        # Each card remembers its position in the list of _all_ cards.
        # It is used when selecting the card from the list of _unconfigured_
        # ones (which may be smaller). #102945.
        Ops.set(one, "num", num)
        # Temporary solution for s390: #40587
        if Arch.s390
          Ops.set(
            one,
            "name",
            DistinguishedName(Ops.get_string(one, "name", ""), card)
          )
        end
        # modem
        if controller == "modem"
          Ops.set(one, "device_name", Ops.get_string(card, "dev_name", ""))
          Ops.set(one, "drivers", Ops.get_list(card, "drivers", []))
          speed = Ops.get_integer(resource, ["baud", 0, "speed"], 57600)
          # :-) have to check .probe and libhd if this confusion is
          # really necessary. maybe a pppd bug too? #148893
          if speed == 12000000
            speed = 57600
            Builtins.y2milestone(
              "Driving faster than light is prohibited on this planet."
            )
          end
          Ops.set(one, "speed", speed)
          Ops.set(
            one,
            "init1",
            Ops.get_string(resource, ["init_strings", 0, "init1"], "")
          )
          Ops.set(
            one,
            "init2",
            Ops.get_string(resource, ["init_strings", 0, "init2"], "")
          )
          Ops.set(
            one,
            "pppd_options",
            Ops.get_string(resource, ["pppd_option", 0, "option"], "")
          )
        # isdn card
        elsif controller == "isdn"
          drivers = Ops.get_list(card, "isdn", [])
          Ops.set(one, "drivers", drivers)
          Ops.set(one, "sel_drv", 0)
          Ops.set(one, "bus", Ops.get_string(card, "bus", ""))
          Ops.set(one, "io", Ops.get_integer(resource, ["io", 0, "start"], 0))
          Ops.set(one, "irq", Ops.get_integer(resource, ["irq", 0, "irq"], 0))
        # dsl card
        elsif controller == "dsl"
          driver_info = Ops.get_map(card, ["dsl", 0], {})
          translate_mode = { "capiadsl" => "capi-adsl", "pppoe" => "pppoe" }
          m = Ops.get_string(driver_info, "mode", "")
          Ops.set(one, "pppmode", Ops.get(translate_mode, m, m)) 
          # driver_info["name"]:"" has no use here??
        # treat the rest as a network card
        elsif controller != ""
          # drivers:
          # Although normally there is only one module
          # (one=$[active:, module:, options:,...]), the generic
          # situation is: one or more driver variants (exclusive),
          # each having one or more modules (one[drivers])

          # only drivers that are not marked as broken (#97540)
          drivers = Builtins.filter(Ops.get_list(card, "drivers", [])) do |d|
            # ignoring more modules per driver...
            module0 = Ops.get_list(d, ["modules", 0], []) # [module, options]
            brk = Builtins.contains(
              broken_modules,
              Ops.get_string(module0, 0, "")
            )
            if brk
              Builtins.y2milestone("In BrokenModules, skipping: %1", module0)
            end
            !brk
          end

          if drivers == []
            Builtins.y2milestone("No good drivers found") 
            # #153235
            # fail, unless we are in xen (it has the driver built in)
            # or PPC (#bnc#361063)
            #		card_ok = Arch::is_xenU () || Arch::ppc();
          else
            Ops.set(one, "drivers", drivers)

            driver = Ops.get_map(drivers, 0, {})
            Ops.set(one, "active", Ops.get_boolean(driver, "active", false))
            module0 = Ops.get_list(driver, ["modules", 0], []) # [module, options]
            Ops.set(one, "module", Ops.get_string(module0, 0, ""))
            Ops.set(one, "options", Ops.get_string(module0, 1, ""))
          end

          # FIXME: this should be also done for modems and others
          # FIXME: #13571
          hp = Ops.get_string(card, "hotplug", "")
          if hp == "pcmcia" || hp == "cardbus"
            Ops.set(one, "hotplug", "pcmcia")
          elsif hp == "usb"
            Ops.set(one, "hotplug", "usb")
          end

          # store the BUS type
          bus = Ops.get_string(
            card,
            "bus_hwcfg",
            Ops.get_string(card, "bus", "")
          )
          if bus == "PCI"
            bus = "pci"
          elsif bus == "USB"
            bus = "usb"
          elsif bus == "Virtual IO"
            bus = "vio"
          end
          Ops.set(one, "bus", bus)

          Ops.set(one, "busid", Ops.get_string(card, "sysfs_bus_id", ""))
          Ops.set(
            one,
            "mac",
            Ops.get_string(resource, ["hwaddr", 0, "addr"], "")
          )
          # is the cable plugged in? nil = don't know
          Ops.set(one, "link", Ops.get(resource, ["link", 0, "state"]))

          # Wireless Card Features
          Ops.set(
            one,
            "wl_channels",
            Ops.get(resource, ["wlan", 0, "channels"])
          )
          #one["wl_frequencies"] = resource["wlan", 0, "frequencies"]:nil;
          Ops.set(
            one,
            "wl_bitrates",
            Ops.get(resource, ["wlan", 0, "bitrates"])
          )
          Ops.set(
            one,
            "wl_auth_modes",
            Ops.get(resource, ["wlan", 0, "auth_modes"])
          )
          Ops.set(
            one,
            "wl_enc_modes",
            Ops.get(resource, ["wlan", 0, "enc_modes"])
          )
        end
        # filter out device with virtio_pci Driver and no Device File (bnc#585506)
        if Ops.get_string(one, "module", "") == "virtio_pci" &&
            Ops.get_string(one, "dev_name", "") == ""
          card_ok = false
          Builtins.y2milestone(
            "Filtering out virtio device without device file."
          )
        end
        # filter out device with chelsio Driver and no Device File or which cannot networking(bnc#711432)
        if Ops.get_string(one, "module", "") == "cxgb4" &&
            Ops.get_string(one, "dev_name", "") == "" ||
            Ops.get_integer(card, "vendor_id", 0) == 70693 &&
              Ops.get_integer(card, "device_id", 0) == 82178
          card_ok = false
          Builtins.y2milestone(
            "Filtering out Chelsio device without device file."
          )
        end
        # exception to filter out uicv devices (bnc#585363)
        if Ops.get_string(card, "device", "") == "IUCV" &&
            Ops.get_string(card, "sysfs_bus_id", "") != "netiucv"
          card_ok = false
          Builtins.y2milestone(
            "Filtering out iucv device different from netiucv."
          )
        end
        Builtins.y2debug("found device: %1", one)
        if card_ok
          Ops.set(_Hardware, Builtins.size(_Hardware), one)
          num = Ops.add(num, 1)
        else
          Builtins.y2milestone("Filtering out: %1", card)
        end
      end

      # if there is wlan, put it to the front of the list
      # that's because we want it proposed and currently only one card
      # can be proposed
      found = false
      i = 0
      Builtins.foreach(_Hardware) do |h|
        if Ops.get_string(h, "type", "") == "wlan"
          found = true
          raise Break
        end
        i = Ops.add(i, 1)
      end
      if found
        temp = Ops.get(_Hardware, 0, {})
        Ops.set(_Hardware, 0, Ops.get(_Hardware, i, {}))
        Ops.set(_Hardware, i, temp)
        # adjust mapping: #98852, #102945
        Ops.set(_Hardware, [0, "num"], 0)
        Ops.set(_Hardware, [i, "num"], i)
      end

      Builtins.y2debug("Hardware=%1", _Hardware)
      deep_copy(_Hardware)
    end

    # TODO - begin:
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
    # TODO - end

    # Return list of all interfaces present in the system (not only configured ones as NetworkInterfaces::List does).
    #
    # @return [Array] of interface names.
    def GetAllInterfaces
      result = RunAndRead("ls /sys/class/net")

      Ops.get_boolean(result, "exit", false) ?
        Ops.get_list(result, "output", []) :
        []
    end

    def SetLinkUp(dev_name)
      Run(Builtins.sformat("ip link set %1 up", dev_name))
    end

    def SetLinkDown(dev_name)
      Run(Builtins.sformat("ip link set %1 down", dev_name))
    end

    def SetAllLinksUp
      interfaces = GetAllInterfaces()
      ret = Ops.greater_than(Builtins.size(interfaces), 0)

      Builtins.foreach(interfaces) do |ifc|
        Builtins.y2milestone("Setting link up for interface %1", ifc)
        ret = SetLinkUp(ifc) && ret
      end

      ret
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


    # Check if we're running in "normal" stage with NM
    # see bnc#433084
    # if listed any items, disable them, if show_popup, show warning popup

    def disableItemsIfNM(items, show_popup)
      items = deep_copy(items)
      disable = true
      if Mode.normal && NetworkService.IsManaged
        Builtins.foreach(items) { |w| UI.ChangeWidget(Id(w), :Enabled, false) }
        if show_popup
          Popup.Warning(
            _(
              "Network is currently controlled by NetworkManager and its settings \n" +
                "cannot be edited by YaST.\n" +
                "\n" +
                "To edit the settings, use the NetworkManager connection editor or\n" +
                "switch the network setup method to Traditional with ifup.\n"
            )
          )
          UI.FakeUserInput({ "ID" => "global" })
        end
      else
        disable = false
      end
      disable
    end
  end
end
