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
# File:	modules/ISDN.ycp
# Package:	Network configuration
# Summary:	ISDN data
# Authors:	Michal Svec  <msvec@suse.cz>
#		Karsten Keil <kkeil@suse.de>
#
#
# Representation of the configuration of ISDN.
# Input and output routines.
require "yast"

module Yast
  class ISDNClass < Module
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Provider"
      Yast.import "Progress"
      Yast.import "Summary"
      Yast.import "PackageSystem"
      Yast.import "SuSEFirewall4Network"

      #-------------
      # GLOBAL DATA

      @proposal_valid = false

      # hold current device settings
      #
      # handled items are
      # line specific
      # PROTOCOL     D-channel protocol
      # AREACODE     international area code
      # DIALPREFIX   dialprefixfor PBX setups
      # hw specific
      # PARA_IO	IO address for legacy ISA
      # PARA_MEMBASE memory base address for legacy ISA
      # PARA_IRQ     IRQ number for legacy ISA
      # PARA_TYPE    card type
      # PARA_SUBTYPE card sub type
      # NAME         full card name
      # DRIVER       driver module name
      # STARTMODE    "auto"|"manual"|"hotplug"
      # DEBUG        debuglevel
      # UDI       unique hw id
      #

      @hw_device = {}

      # global dialprefix default value for current
      @global_dp = ""
      # global areacode default value for current
      @global_ac = ""
      # global start mode
      @global_sm = ""

      # ISDN database based on CDB
      #
      # map with two keys, of maps:
      # Cards:
      #   map, keyed by integers, of maps:
      #   CardID:	integer (the key)
      #   VendorRef:	integer
      #   bus:	string (ISA)
      #   class:	string (ISDN Single/Multiple Basic Rate)
      #   device:	integer
      #   driver:	list of driver maps
      #   features:	integer
      #   lines:	integer
      #   longname:	string
      #   name:	string
      #   revision:	integer
      #   subdevice:	integer
      #   subvendor:	integer
      #   vendor:	integer
      # Vendors:
      #   map, keyed by integers, of maps:
      #   VendorID:	integer (the key)
      #   name:	string
      #   refcnt:	integer
      #   shortname:	string
      #
      #
      # driver map:
      #   IO:	list<string>
      #   IRQ:	list<string>
      #   MEMBASE:	list<string>
      #   description: string
      #   drvid:	integer
      #   info:	string
      #   mod_name:	string
      #   name:	string
      #   need_pkg:	list<string>
      #   protocol:	list<string>
      #   subtype:	integer
      #   type:	integer
      @ISDNCDB = {}


      # hold current interface settings
      #
      # handled items are
      # IPADDR         local IP address
      # REMOTE_ADDR    remote IP address
      # DEFAULTROUTE   default route yes/no
      # DYNAMICIP      dynamic IP assignment yes/no
      # PROTOCOL       encapsulation "rawip" | "syncppp"
      # MSN            own phone number
      # CHARGEHUP      try to hangup on idle just before next charge
      # CALLBACK       callback mode
      # CBDELAY        callback delay
      # STARTMODE      auto | manual | hotplug
      # USERCONTROL    controllable bt user yes/no
      # MULTILINK      channel bundling yes/no
      # PROVIDER       default provider filename
      # IPPPD_OPTIONS  additional ipppd options
      #
      @interface = {}

      # set if here is any ISDN interface

      @provider_file = ""

      # current item
      @type = ""
      @device = ""

      # Flag for Fritz!card DSL configuration
      @have_dsl = false
      @only_dsl = false
      @DRDSLrun = false
      @installpackages = []

      # Which operation is pending?
      @operation = nil

      # If the interface or provider configuration is skipped
      @skip = false

      #--------------
      # PRIVATE DATA

      # Hardware information
      # @see #ReadHardware
      @Hardware = []

      # Config information
      # @see #ReadDevices
      @Devices = {}

      # deleted devices
      @DeletedDevices = []

      # configured ISDN net devices
      @NetDevs = []

      # Abort function
      # return boolean return true if abort
      @AbortFunction = nil

      # Data was modified?
      @modified_hw = false
      @modified_if = false

      @description = ""
      @unique = ""
      @hotplug = ""
      @alias = ""
      @Requires = [] # because of hardware.ycp

      Yast.include self, "network/devices.rb"
      Yast.include self, "network/hardware.rb"
      Yast.include self, "network/routines.rb"

      Yast.include self, "network/complex.rb"

      Yast.include self, "network/isdn/config.rb"
      Yast.include self, "network/isdn/routines.rb"

      Yast.include self, "network/runtime.rb"
    end

    #------------------
    # GLOBAL FUNCTIONS

    # Data was modified?
    # @return true if modified
    def Modified
      Builtins.y2debug("modified(hw,if)=%1,%2", @modified_hw, @modified_if)
      @modified_hw || @modified_if
    end

    # @return name of interface
    def IfaceName(num, iface)
      iface = deep_copy(iface)
      protocol = Ops.get_string(iface, "PROTOCOL", "")
      format = { "syncppp" => "ippp%1", "rawip" => "isdn%1" }
      Builtins.sformat(Ops.get_string(format, protocol, "unknown%1"), num)
    end

    # Locate interfaces of the given key and value
    # @param [String] key interface key
    # @param [String] val interface value
    # @return [Array] of devices with key=val
    def Locate(key, val)
      netdevs = Convert.convert(
        Ops.get(@Devices, "net", {}),
        :from => "map",
        :to   => "map <string, map>"
      )
      ret = []
      Builtins.foreach(netdevs) do |num, dev|
        if Ops.get_string(dev, key, "") == val
          ret = Builtins.add(ret, IfaceName(num, dev))
        end
      end
      deep_copy(ret)
    end

    # Read all ISDN settings from the SCR
    # @return true on success
    def Read
      # title for ISDN reading current setup progress screen
      caption = _("Initializing ISDN Card Configuration")
      steps = 5

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      Progress.New(
        caption,
        " ",
        steps,
        [
          # stages for the ISDN reading current setup progress screen
          # stage 1/5
          _("Detect devices"),
          # stage 2/5
          _("Read current device configuration"),
          # stage 3/5
          _("Read current connection setup"),
          # stage 4/5
          _("Read firewall settings"),
          # stage 5/5
          _("Read providers")
        ],
        [],
        ""
      )

      @Devices = {}

      return false if Abort()

      # check the environment
      return false if !Confirm.MustBeRoot

      # step 1 in reading current ISDN setup
      ProgressNextStage(_("Detecting ISDN cards..."))
      @Hardware = ReadHardware("isdn")
      Builtins.sleep(sl)

      return false if Abort()
      # step 2 in reading current ISDN setup
      ProgressNextStage(_("Reading current device configuration..."))
      ReadISDNConfig("cfg-contr")
      NetworkService.Read
      Builtins.sleep(sl)

      return false if Abort()
      # step 3 in reading current ISDN setup
      ProgressNextStage(_("Reading current connection setup..."))
      ReadISDNConfig("cfg-net")
      Builtins.sleep(sl)

      return false if Abort()
      # step 4 in reading current ISDN setup
      ProgressNextStage(_("Reading firewall settings..."))
      progress_orig = Progress.set(false)
      SuSEFirewall4Network.Read
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # step 5 in reading current ISDN setup
      ProgressNextStage(_("Reading providers..."))
      Provider.Read
      Builtins.sleep(sl)

      return false if Abort()
      # last step in reading current ISDN setup
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      return false if Abort()
      @modified_hw = false
      @modified_if = false
      true
    end


    # Only write configuration without starting any init scripts and SuSEconfig
    # @return true on success

    def WriteOnly
      WriteISDNConfig("contr")
      WriteISDNConfig("net")
      Provider.Write("isdn")
      true
    end

    # Update the SCR according to network settings
    # @return true on success
    #
    # if start is true, load drivers and interfaces
    def Write(start)
      # install qinternet if there is at least one ISDN device - #161782
      if Ops.greater_than(Builtins.size(Ops.get(@Devices, "contr", {})), 0) &&
          !PackageSystem.Installed("qinternet")
        @installpackages = Builtins.add(@installpackages, "qinternet")
      end

      if @installpackages != nil && @installpackages != [""]
        retp = PackagesInstall(
          Convert.convert(
            @installpackages,
            :from => "list",
            :to   => "list <string>"
          )
        )
        Builtins.y2debug("Packages returns %1", retp)
      end

      haveISDNDev = {} != Ops.get(@Devices, "contr", {})
      if !(@modified_hw || @modified_if || Provider.Modified("isdn"))
        return true
      end
      Builtins.y2milestone("Writing configuration")

      # title for ISDN writing current setup progress screen
      caption = _("Saving ISDN Configuration")
      cmd = ""

      sl = 0 # 1000; /* TESTING

      steps = 7
      plist = []
      haveISDNif = {} != Ops.get(@Devices, "net", {})

      # stages for the ISDN writing current setup progress screen with start
      # stage 1/13
      plist = Builtins.add(plist, _("Stop ISDN networking"))
      # stage 2/13
      plist = Builtins.add(plist, _("Stop ISDN subsystem"))
      # stage 3/13
      plist = Builtins.add(plist, _("Write controller configuration"))
      # stage 4/13
      plist = Builtins.add(plist, _("Write interface configuration"))
      # stage 5/13
      plist = Builtins.add(plist, _("Write firewall"))
      # stage 6/13
      plist = Builtins.add(plist, _("Write providers"))
      # stage 7/13
      plist = Builtins.add(plist, _("Update configuration"))
      if start
        steps = 8
        # stage 8/13
        plist = Builtins.add(plist, _("Start ISDN subsystem"))

        if @DRDSLrun
          # stage 9/13
          plist = Builtins.add(plist, _("Run drdsl"))
          steps = 9
        end
        if haveISDNif
          steps = Ops.add(steps, 4)
          # stage 11/13
          plist = Builtins.add(plist, _("Set up network services"))
          # stage 11/13
          plist = Builtins.add(plist, _("Set up smpppd"))
          # stage 12/13
          plist = Builtins.add(plist, _("Start ISDN networking"))
          # Progress stage 9
          plist = Builtins.add(plist, _("Activate network services"))
        end
      end

      Progress.New(caption, " ", steps, plist, [], "")
      return false if Abort()
      # step 1 in writing current ISDN setup
      ProgressNextStage(_("Stopping ISDN networking..."))
      cmd = Builtins.sformat("/etc/init.d/network stop -o type=isdn")
      SCR.Execute(path(".target.bash"), cmd)
      cmd = Builtins.sformat("/etc/init.d/network stop -o type=ippp")
      SCR.Execute(path(".target.bash"), cmd)
      Builtins.sleep(sl)

      return false if Abort()
      # step 2 in writing current ISDN setup
      ProgressNextStage(_("Stopping ISDN subsystem..."))
      if @modified_hw
        cmd = Builtins.sformat("/etc/init.d/isdn unload")
        SCR.Execute(path(".target.bash"), cmd)
      end
      Builtins.sleep(sl)

      return false if Abort()
      # step 3 in writing current ISDN setup
      ProgressNextStage(_("Writing controller configuration..."))
      WriteISDNConfig("contr") if @modified_hw
      Builtins.sleep(sl)

      return false if Abort()
      # step 4 in writing current ISDN setup
      ProgressNextStage(_("Writing interface configuration..."))
      WriteISDNConfig("net")
      Builtins.sleep(sl)

      return false if Abort()
      # step 5 in writing current ISDN setup
      ProgressNextStage(_("Writing firewall settings..."))
      progress_orig = Progress.set(false)
      SuSEFirewall4Network.Write
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # step 6 in writing current ISDN setup
      ProgressNextStage(_("Writing providers..."))
      Provider.Write("isdn") if Provider.Modified("isdn")
      Builtins.sleep(sl)

      return false if Abort()
      # step 7 in writing current ISDN setup
      ProgressNextStage(_("Updating configuration..."))
      SCR.Execute(
        path(".target.bash"),
        "/etc/sysconfig/isdn/scripts/postprocess.isdn"
      )
      Builtins.sleep(sl)

      return false if Abort()

      if start
        # step 8 in writing current ISDN setup
        ProgressNextStage(_("Loading ISDN driver..."))
        if @modified_hw
          cmd = Builtins.sformat("/etc/init.d/isdn start -o all")
          SCR.Execute(path(".target.bash"), cmd)
          @modified_hw = false
        end
        Builtins.sleep(sl)

        return false if Abort()
        if @DRDSLrun
          # step 9 in writing current ISDN setup
          ProgressNextStage(_("Running drdsl (could take over a minute)..."))
          # Avoid some race. kkeil:
          # I got one customer report about this race, but never
          # was able to reproduce, on the customer side this sleep
          # fixes the problem. It seems that after loading the
          # firmware the controller does some more internal
          # stuff. If drdsl is called too early, it will confuse
          # the controller and it does not get valid values.
          # One second is small compared to 10-20s for drdsl itself.
          Builtins.sleep(1000)
          cmd = Builtins.sformat("/usr/sbin/drdsl -q")
          SCR.Execute(path(".target.bash"), cmd)
          Builtins.sleep(sl)
        end
        if haveISDNif
          return false if Abort()
          # step 10 in writing current ISDN setup
          ProgressNextStage(_("Setting up network services..."))
          NetworkService.EnableDisable
          Builtins.sleep(sl)

          return false if Abort()
          # step 11 in writing current ISDN setup
          ProgressNextStage(_("Setting up smpppd(8)..."))
          SetupSMPPPD(true)
          Builtins.sleep(sl)

          return false if Abort()
          # step 12 in writing current ISDN setup
          ProgressNextStage(_("Loading ISDN network..."))
          cmd = Builtins.sformat("/etc/init.d/network start -o type=isdn")
          SCR.Execute(path(".target.bash"), cmd)
          cmd = Builtins.sformat("/etc/init.d/network start -o type=ippp")
          SCR.Execute(path(".target.bash"), cmd)
          @modified_if = false
          Builtins.sleep(sl)

          return false if Abort()
          # Progress step 9
          ProgressNextStage(_("Activating network services..."))
          write_only = false
          if !write_only
            #		NetworkModules::HwUp (); // this is needed too
            NetworkService.StartStop
          end
          Builtins.sleep(sl)
        end
      end

      return false if Abort()
      # last step in writing current ISDN setup
      if haveISDNDev
        cmd = Builtins.sformat("/sbin/insserv isdn") # #104590
        SCR.Execute(path(".target.bash"), cmd)
      else
        cmd = Builtins.sformat("/sbin/insserv -r capisuite")
        SCR.Execute(path(".target.bash"), cmd)
        cmd = Builtins.sformat("/sbin/insserv -r isdn")
        SCR.Execute(path(".target.bash"), cmd)
      end
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      return false if Abort()
      true
    end

    # Test the given card settings
    # @return true on success
    def TestDev(dev)
      # title for ISDN testing current setup progress screen
      caption = Builtins.sformat(_("Testing ISDN Configuration %1"), dev)
      cmd = ""
      details = ""
      out = {}
      result = 1
      steps = 5

      sl = 500 #1000;
      Builtins.sleep(sl)

      Progress.New(
        caption,
        " ",
        steps,
        [
          # stages for the ISDN testing current setup progress screen
          # stage 1/5
          _("Write controller configuration"),
          # stage 2/5
          _("Stop ISDN network"),
          # stage 3/5
          _("Unload ISDN driver"),
          # stage 4/5
          _("Load controller"),
          # stage 5/5
          _("Unload controller")
        ],
        [],
        ""
      )

      return false if Abort()
      # step 1 in testing current ISDN setup
      ProgressNextStage(_("Writing controller configuration..."))
      WriteOneISDNConfig(dev)
      Builtins.sleep(sl)

      return false if Abort()
      # step 2 in testing current ISDN setup
      ProgressNextStage(_("Stopping ISDN network..."))
      cmd = Builtins.sformat("/etc/init.d/network stop -o type=isdn")
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      details = Ops.add(Ops.add(details, cmd), "\n")
      details = Ops.add(details, Ops.get_string(out, "stdout", ""))
      details = Ops.add(details, Ops.get_string(out, "stderr", ""))
      details = Ops.add(details, "\n")
      cmd = Builtins.sformat("/etc/init.d/network stop -o type=ippp")
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      details = Ops.add(Ops.add(details, cmd), "\n")
      details = Ops.add(details, Ops.get_string(out, "stdout", ""))
      details = Ops.add(details, Ops.get_string(out, "stderr", ""))
      details = Ops.add(details, "\n")
      Builtins.sleep(sl)

      return false if Abort()
      # step 3 in testing current ISDN setup
      ProgressNextStage(_("Unloading ISDN driver..."))
      cmd = Builtins.sformat("/etc/init.d/isdn unload")
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      details = Ops.add(Ops.add(details, cmd), "\n")
      details = Ops.add(details, Ops.get_string(out, "stdout", ""))
      details = Ops.add(details, Ops.get_string(out, "stderr", ""))
      details = Ops.add(details, "\n")
      Builtins.sleep(sl)

      return false if Abort()
      # step 4 in testing current ISDN setup
      ProgressNextStage(_("Loading controller..."))
      cmd = Builtins.sformat("/etc/init.d/isdn start %1 -o all", dev)
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      details = Ops.add(Ops.add(details, cmd), "\n")
      details = Ops.add(details, Ops.get_string(out, "stdout", ""))
      details = Ops.add(details, Ops.get_string(out, "stderr", ""))
      details = Ops.add(details, "\n")
      result = Ops.get_integer(out, "exit", 1)
      Builtins.sleep(sl)

      return false if Abort()
      # step 5 in testing current ISDN setup
      ProgressNextStage(_("Unloading controller..."))
      cmd = Builtins.sformat("/etc/init.d/isdn unload")
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      details = Ops.add(Ops.add(details, cmd), "\n")
      details = Ops.add(details, Ops.get_string(out, "stdout", ""))
      details = Ops.add(details, Ops.get_string(out, "stderr", ""))
      details = Ops.add(details, "\n")
      Builtins.sleep(sl)

      return false if Abort()
      # last step in testing current ISDN setup
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      return false if Abort()
      display_testresult(result, details)
      @operation = :testdev
      true
    end

    # default settings of hw device
    #
    # @param map of parameters
    #
    def set_cardparameters(cfg)
      cfg = deep_copy(cfg)
      ac = Ops.get_string(cfg, "AREACODE", @global_ac)
      @global_ac = ac if @global_ac == ""
      Ops.set(cfg, "AREACODE", ac)

      dp = Ops.get_string(cfg, "DIALPREFIX", @global_dp)
      @global_dp = dp if @global_dp == ""
      Ops.set(cfg, "DIALPREFIX", dp) if dp != ""

      sm = Ops.get_string(cfg, "STARTMODE", "auto")
      @global_sm = "hotplug" if sm == "hotplug"
      sm = "auto" if sm == ""
      Ops.set(cfg, "STARTMODE", sm)

      deep_copy(cfg)
    end

    # default settings of interface
    #
    # @param map of parameters
    #
    def set_ifparameters(cfg)
      cfg = deep_copy(cfg)
      sm = Ops.get_string(cfg, "STARTMODE", "manual")
      @global_sm = sm if @global_sm == ""
      sm = "auto" if sm == ""
      Ops.set(cfg, "STARTMODE", sm)

      @provider_file = Ops.get_string(cfg, "PROVIDER", "")

      deep_copy(cfg)
    end

    # copy detected hw settings to current item
    #
    # @param map of detected hw settings
    #
    def set_hwparameters(hw)
      hw = deep_copy(hw)
      # Fixme parameter lookup for ISA hardware
      Ops.set(@hw_device, "PARA_TYPE", Builtins.sformat("%1", get_i4ltype(hw)))
      Ops.set(
        @hw_device,
        "PARA_SUBTYPE",
        Builtins.sformat("%1", get_i4lsubtype(hw))
      )
      Ops.set(
        @hw_device,
        "NAME",
        Builtins.sformat("%1", Ops.get_string(hw, "name", "unknown"))
      )
      Ops.set(@hw_device, "UNIQUE", Ops.get_string(hw, "unique", ""))

      nil
    end

    # Select the given hardware item or clean up structures
    # @param [Fixnum] which item to be chosen
    # FIXME: -> routines/hardware.ycp (?)
    # sel["name"] for the interface
    def SelectHW(which)
      sel = {}

      sel = Ops.get(@Hardware, which, {}) if which != nil

      if Ops.greater_than(which, Builtins.size(@Hardware)) ||
          Ops.less_than(which, 0)
        Builtins.y2error(
          "Item not found in Hardware: %1 (%2)",
          which,
          Builtins.size(@Hardware)
        )
      end

      @type = "contr"
      @device = Builtins.sformat("%1%2", @type, GetFreeDevice(@type))
      @hw_device = set_cardparameters({})
      set_hwparameters(sel)
      @operation = :add

      nil
    end

    # selects next free cfg-contr<N>
    # and initialisize all cfg-contr<N> values
    # @return true if a free cfg-contr<N> was found
    def Add
      @type = "contr"
      @device = Builtins.sformat("%1%2", @type, GetFreeDevice(@type))
      Builtins.y2internal("New Added device %1", @device)
      @hw_device = set_cardparameters({})
      @operation = :add
      true
    end

    # selects cfg-<dev> for edit
    # @param  string dev device to edit
    # @return true if cfg-<dev> was found
    def Edit(dev)
      typ = NetworkInterfaces.device_type(dev)
      #    string num = NetworkInterfaces::device_num(dev);

      typemap = Ops.get(@Devices, typ, {})
      if !Builtins.haskey(typemap, dev)
        Builtins.y2error("Key not found: %1", dev)
        return false
      end
      @hw_device = Ops.get_map(typemap, dev, {})

      Builtins.y2debug("Hardware: %1", @Hardware)

      @device = dev
      @type = typ
      @hw_device = set_cardparameters(@hw_device)
      Builtins.y2debug("devmap=%1", @hw_device)
      @operation = :edit
      true
    end

    # selects cfg-<item> for delete
    # @param  string item item to delete
    # @return true if cfg-<delete> was found
    def Delete(item)
      @operation = nil
      typ = NetworkInterfaces.device_type(item)
      #    string num = NetworkInterfaces::device_num(item);

      typemap = Ops.get(@Devices, typ, {})
      if !Builtins.haskey(typemap, item)
        Builtins.y2error("Key not found: %1", item)
        return false
      end
      @interface = Ops.get_map(typemap, item, {}) if @type == "net"
      @type = typ
      @device = item
      @operation = :delete
      true
    end

    # selects next free cfg-net<N>
    # and initialisize all cfg-net<N> values
    # @param proto "syncppp" or "rawip"
    # @return true if a free cfg-net<N> was found
    def AddIf(proto)
      @type = "net"
      @device = Builtins.sformat("%1%2", @type, GetFreeDevice(@type))
      @interface = { "PROTOCOL" => proto, "USERCONTROL" => "yes" }
      @interface = set_ifparameters(@interface)
      @operation = :addif
      Builtins.y2milestone("Adding network configuration %1", @device)
      true
    end

    # selects interface cfg-<item>
    # @param  string item interface to select
    # @return true if cfg-<item> was found
    def SelIf(item)
      typ = NetworkInterfaces.device_type(item)
      num = NetworkInterfaces.device_num(item)

      typemap = Ops.get(@Devices, typ, {})
      if !Builtins.haskey(typemap, num)
        Builtins.y2error("Key not found: %1", item)
        return false
      end
      @interface = Ops.get_map(typemap, num, {})
      # interface settings
      @interface = set_ifparameters(@interface)
      Ops.set(
        @interface,
        "NAME",
        BuildDescription(typ, num, @interface, @Hardware)
      )
      @device = num
      @type = typ
      true
    end

    # selects interface cfg-<item> for edit
    # @param  string item interface to edit
    # @return true if cfg-<item> was found
    def EditIf(item)
      if SelIf(item)
        @operation = :editif
        return true
      end
      false
    end

    # commit changes of the current item
    # defined by type device
    # @return true if the current item was found
    def Commit
      Builtins.y2debug("Commit(%1) dev:%2%3", @operation, @type, @device)
      Builtins.y2debug("skip %1", @skip)
      return true if @operation == nil

      if @skip && @operation != :add && @operation != :edit &&
          @operation != :delete
        @skip = false
        return true
      end
      if @operation == :edit || @operation == :editif || @operation == :addproc
        typemap = Ops.get(@Devices, @type, {})
        Builtins.y2debug("typemap %1", typemap)
        if !Builtins.haskey(typemap, @device)
          Builtins.y2error("Key not found: %1", @device)
          return false
        end
      end
      if @operation == :add || @operation == :edit
        ac = Ops.get_string(@hw_device, "AREACODE", "")
        @global_ac = ac if ac != ""
        dp = Ops.get_string(@hw_device, "DIALPREFIX", "")
        @global_dp = dp
        sm = Ops.get_string(@hw_device, "STARTMODE", "")
        @global_sm = "hotplug" if sm == "hotplug"
        @global_sm = "manual" if sm == "manual" && @global_sm == "auto"

        ChangeDevice(@type, @device, @hw_device, @operation == :add)
        @modified_hw = true
      elsif @operation == :addif || @operation == :editif
        Ops.set(@interface, "PROVIDER", @provider_file)
        ChangeDevice(@type, @device, @interface, @operation == :addif)
        @modified_if = true 

        # } else if(operation == `addprov || operation == `editprov) {

        # handled in Provider module
      elsif @operation == :testdev
        Builtins.y2debug("op testdev")
      elsif @operation == :delete
        if @type == "net"
          p = Ops.get_string(@interface, "PROTOCOL", "")
          devnam = ""
          if p == "syncppp"
            devnam = Builtins.sformat("ippp%1", @device)
          elsif p == "rawip"
            devnam = Builtins.sformat("isdn%1", @device)
          else
            devnam = Builtins.sformat("unknown%1", @device)
          end
          SuSEFirewall4Network.ProtectByFirewall(devnam, "EXT", false)
        end
        DeleteDevice(@type, @device)

        if @type == "contr"
          @modified_hw = true
        else
          @modified_if = true
        end
      else
        Builtins.y2error("Unknown operation: %1", @operation)
        return false
      end

      @operation = nil
      true
    end


    def Import(settings)
      settings = deep_copy(settings)
      Provider.Import("isdn", Ops.get_map(settings, "_PROVIDERS", {}))
      @Devices = Convert.convert(
        Builtins.add(settings, "_PROVIDERS", nil),
        :from => "map",
        :to   => "map <string, map>"
      )
      true
    end


    def Export
      _PROVIDERS = Provider.Export("isdn")
      Builtins.add(@Devices, "_PROVIDERS", _PROVIDERS)
    end

    # List of configured interface entries
    # @return [Array<Strings>]
    def NetDeviceList
      typemap = Convert.convert(
        Ops.get(@Devices, "net", {}),
        :from => "map",
        :to   => "map <string, map>"
      )

      @NetDevs = []
      Builtins.maplist(typemap) do |num, devmap|
        prot = Ops.get_string(devmap, "PROTOCOL", "")
        devnam = ""
        if prot == "syncppp"
          devnam = Builtins.sformat("ippp%1", num)
        elsif prot == "rawip"
          devnam = Builtins.sformat("isdn%1", num)
        else
          devnam = Builtins.sformat("unkown%1", num)
        end
        @NetDevs = Builtins.add(@NetDevs, devnam)
      end
      deep_copy(@NetDevs) 
      # better: return maplist (string num, map devmap, typemap, ``( IfaceName (num, devmap) ));
    end

    # Build a textual summary and a list of unconfigured cards
    # @return summary of the current configuration
    def Summary(split)
      BuildSummaryDevs(@Devices, @Hardware, split, false)
    end


    def OverviewDev
      res = Builtins.filter(
        Convert.convert(
          BuildOverviewDevs(@Devices, @Hardware),
          :from => "list",
          :to   => "list <term>"
        )
      ) do |i|
        Builtins.issubstring(Ops.get_string(i, [0, 0], ""), "contr")
      end
      Builtins.maplist(
        Convert.convert(res, :from => "list", :to => "list <term>")
      ) do |card|
        id = Ops.get_string(card, [0, 0], "")
        desc = [
          Ops.get_string(card, 1, ""),
          Ops.get_string(card, 2, ""),
          Ops.get_string(card, 3, "")
        ]
        {
          "id"          => id,
          "rich_descr"  => Ops.get_locale(
            card,
            4,
            Ops.get_locale(desc, 1, _("Unknown"))
          ),
          "table_descr" => desc
        }
      end
    end

    def UnconfiguredDev
      BuildUnconfiguredDevs(@Devices, "isdn", @Hardware)
    end

    def OverviewIf
      res = Builtins.filter(
        Convert.convert(
          BuildOverviewDevs(@Devices, @Hardware),
          :from => "list",
          :to   => "list <term>"
        )
      ) { |i| Builtins.issubstring(Ops.get_string(i, [0, 0], ""), "net") }

      Builtins.maplist(
        Convert.convert(res, :from => "list", :to => "list <term>")
      ) do |card|
        id = Ops.get_string(card, [0, 0], "")
        desc = [
          Ops.get_string(card, 1, ""),
          Ops.get_string(card, 2, ""),
          Ops.get_string(card, 3, "")
        ]
        {
          "id"          => id,
          "rich_descr"  => Ops.get_locale(
            card,
            4,
            Ops.get_locale(desc, 1, _("Unknown"))
          ),
          "table_descr" => desc
        }
      end 

      #return BuildOverview("net");
    end

    # Count of valid interface entries
    # @return count
    def CountIF
      typemap = Ops.get(@Devices, "net", {})

      Builtins.size(typemap)
    end

    # If not allready done set a valid interface
    # @return true  if the selection was successful
    #         false if here aren't any interfaces
    def PrepareInterface
      if Ops.greater_than(Builtins.tointeger(@device), -1) && @type == "net"
        return true
      end
      typemap = Convert.convert(
        Ops.get(@Devices, "net", {}),
        :from => "map",
        :to   => "map <string, map>"
      )
      return false if 0 == Builtins.size(typemap)
      id = ""
      Builtins.maplist(typemap) do |num, devmap|
        id = Builtins.sformat("net%1", num)
      end
      SelIf(id)
    end

    # Displays a popup to select one interface to be the
    # current interface
    # @param [Boolean] auto if true and only one interface exist
    #             take it without a extra dialog
    # @return true  if the selection war successful
    #         false if here aren't any interfaces
    def SelectInterface(auto)
      typemap = Convert.convert(
        Ops.get(@Devices, "net", {}),
        :from => "map",
        :to   => "map <string, map>"
      )
      id = ""
      s = Builtins.size(typemap)

      Builtins.y2debug("device = %1", @device)
      Builtins.y2debug("typemap = %1", typemap)

      return false if s == 0
      if auto && s == 1
        Builtins.maplist(typemap) do |num, devmap|
          id = Builtins.sformat("net%1", num)
        end
        return SelIf(id)
      end

      ifl = Builtins.maplist(typemap) do |num, devmap|
        p = Ops.get_string(devmap, "PROTOCOL", "")
        devid = Builtins.sformat("net%1", num)
        devnam = ""
        if p == "syncppp"
          devnam = Builtins.sformat("ippp%1", num)
        elsif p == "rawip"
          devnam = Builtins.sformat("isdn%1", num)
        else
          devnam = Builtins.sformat("unknown%1", num)
        end
        Item(Id(devid), devnam, num == @device)
      end
      Builtins.y2debug("ifl=%1", ifl)
      # label of a single combo box in a popup to select a interface for an edit/delete operation
      id = select_fromlist_popup(_("&Select Interface"), ifl)
      SelIf(id)
    end

    def GetInterface4Provider(prov)
      ifn = ""
      typemap = Convert.convert(
        Ops.get(@Devices, "net", {}),
        :from => "map",
        :to   => "map <string, map>"
      )

      Builtins.maplist(typemap) do |num, devmap|
        if prov == Ops.get_string(devmap, "PROVIDER", "")
          if "syncppp" == Ops.get_string(devmap, "PROTOCOL", "")
            ifn = Builtins.sformat("ippp%1", num)
          else
            ifn = Builtins.sformat("isdn%1", num)
          end
        end
        false
      end
      ifn
    end

    publish :variable => :proposal_valid, :type => "boolean"
    publish :variable => :hw_device, :type => "map"
    publish :variable => :global_dp, :type => "string"
    publish :variable => :global_ac, :type => "string"
    publish :variable => :global_sm, :type => "string"
    publish :variable => :ISDNCDB, :type => "map"
    publish :variable => :interface, :type => "map"
    publish :variable => :provider_file, :type => "string"
    publish :variable => :type, :type => "string"
    publish :variable => :device, :type => "string"
    publish :variable => :have_dsl, :type => "boolean"
    publish :variable => :only_dsl, :type => "boolean"
    publish :variable => :DRDSLrun, :type => "boolean"
    publish :variable => :installpackages, :type => "list"
    publish :variable => :operation, :type => "symbol"
    publish :variable => :skip, :type => "boolean"
    publish :variable => :AbortFunction, :type => "block <boolean>"
    publish :function => :Modified, :type => "boolean ()"
    publish :variable => :Requires, :type => "list <string>"
    publish :function => :GetFreeDevices, :type => "list <string> (string, integer)"
    publish :function => :GetFreeDevice, :type => "string (string)"
    publish :function => :ChangeDevice, :type => "boolean (string, string, map, boolean)"
    publish :function => :DeleteDevice, :type => "boolean (string, string)"
    publish :function => :ReadISDNConfig, :type => "boolean (string)"
    publish :function => :WriteISDNConfig, :type => "boolean (string)"
    publish :function => :WriteOneISDNConfig, :type => "boolean (string)"
    publish :function => :Locate, :type => "list <string> (string, string)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :WriteOnly, :type => "boolean ()"
    publish :function => :Write, :type => "boolean (boolean)"
    publish :function => :TestDev, :type => "boolean (string)"
    publish :function => :SelectHW, :type => "void (integer)"
    publish :function => :Add, :type => "boolean ()"
    publish :function => :Edit, :type => "boolean (string)"
    publish :function => :Delete, :type => "boolean (string)"
    publish :function => :AddIf, :type => "boolean (string)"
    publish :function => :SelIf, :type => "boolean (string)"
    publish :function => :EditIf, :type => "boolean (string)"
    publish :function => :Commit, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :NetDeviceList, :type => "list <string> ()"
    publish :function => :Summary, :type => "list (boolean)"
    publish :function => :OverviewDev, :type => "list ()"
    publish :function => :UnconfiguredDev, :type => "list <map <string, any>> ()"
    publish :function => :OverviewIf, :type => "list ()"
    publish :function => :CountIF, :type => "integer ()"
    publish :function => :PrepareInterface, :type => "boolean ()"
    publish :function => :SelectInterface, :type => "boolean (boolean)"
    publish :function => :GetInterface4Provider, :type => "string (string)"
  end

  ISDN = ISDNClass.new
  ISDN.main
end
