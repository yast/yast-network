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
# File:	modules/DSL.ycp
# Package:	Network configuration
# Summary:	DSL data
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Representation of the configuration of DSL.
# Input and output routines.
require "yast"

module Yast
  class DSLClass < Module
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Confirm"
      Yast.import "NetHwDetection"
      Yast.import "Lan"
      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Provider"
      Yast.import "Progress"
      Yast.import "Summary"
      Yast.import "SuSEFirewall4Network"

      Yast.include self, "network/complex.rb"

      # general stuff
      @description = ""
      @type = ""
      @device = ""
      @unique = ""
      @startmode = "manual"
      @usercontrol = false
      @hotplug = ""
      # FIXME so far does nothing, add code like in Lan and Modem
      @Requires = []

      # Special Capi-ADSL mode -- different presets for the first device.
      # Used for ISDN-DSL combined hardware.
      @capiadsl = nil

      # Ethernet network interface
      @interface = ""

      # VPI/VCI
      @vpivci = ""

      # DSL modem IP (used for PPTP)
      @modemip = "10.0.0.138"

      # PPP mode: pppoe or pppoatm
      @pppmode = "pppoe"

      @PPPDoptions = ""

      # Provider settings
      # authorization settings
      @username = ""
      @password = ""

      # connection settings
      @idletime = 300
      @dialondemand = false
      @dns1 = ""
      @dns2 = ""

      # something already proposed?
      @proposal_valid = false

      #--------------
      # PRIVATE DATA

      # Hardware information
      # @see #ReadHardware
      @Hardware = []

      # FIXME: HW
      @HWDetected = false

      # Abort function
      # return boolean return true if abort
      @AbortFunction = nil

      # Data was modified?
      @modified = false

      # Which operation is pending?
      @operation = nil

      @write_only = false

      Yast.include self, "network/hardware.rb"
      Yast.include self, "network/routines.rb"
      Yast.include self, "network/runtime.rb"
    end

    #------------------
    # GLOBAL FUNCTIONS

    # Data was modified?
    # @return true if modified
    def Modified
      Builtins.y2debug("modified=%1", @modified)
      @modified
    end

    # Read all network settings from the SCR
    # @return true on success
    def Read
      cache = :cache

      # Read dialog caption
      caption = _("Initializing DSL Configuration")
      steps = 5

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/5
          _("Detect DSL devices"),
          # Progress stage 2/5
          _("Read current configuration"),
          # Progress stage 3/5
          _("Read firewall configuration"),
          # Progress stage 4/5
          _("Read providers"),
          # Progress stage 5/5
          _("Read network card configuration")
        ],
        [],
        ""
      )

      return false if Abort()

      # check the environment
      return false if !Confirm.MustBeRoot

      # Progress step 1/5
      ProgressNextStage(_("Detecting DSL devices..."))
      NetHwDetection.Start if !NetHwDetection.running
      @Hardware = Convert.convert(
        Builtins.union(ReadHardware("dsl"), ReadHardware("pppoe")),
        :from => "list",
        :to   => "list <map>"
      )

      # In case of capiadsl we can emulate the detection with the parameters
      # from ISDN. Advantage: we can setup the dialog items correctly.
      @Hardware = Builtins.add(@Hardware, @capiadsl) if @capiadsl != nil
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 2/5
      ProgressNextStage(_("Reading current configuration..."))
      NetworkInterfaces.Read
      NetworkService.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 3/5
      ProgressNextStage(_("Reading firewall configuration..."))
      progress_orig = Progress.set(false)
      SuSEFirewall4Network.Read
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4/5
      ProgressNextStage(_("Reading providers..."))
      Provider.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 5/5
      ProgressNextStage(_("Reading network card configuration..."))
      if !@proposal_valid
        progress_orig2 = Progress.set(false)
        Lan.Read(cache)
        Progress.set(progress_orig2)
      end
      Builtins.sleep(sl)

      # Confirmation: label text (detecting hardware: xxx)
      if Confirm.Detection(_("PPPoE DSL Devices"), "yast-dsl")
        # it doesn't do anything except looking whether probe.pppoe is empty
        # FIXME: HW
        pppoe = Convert.to_list(SCR.Read(path(".probe.pppoe")))
        # FIXME: testing pppoe = [ $["a" : "b"] ];
        if pppoe != nil && Ops.greater_than(Builtins.size(pppoe), 0)
          @HWDetected = true
        end
      end

      return false if Abort()
      # Final progress step
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      return false if Abort()
      @modified = false
      true
    end

    # Update the SCR according to network settings
    # @return true on success
    def Write
      return true if !@modified && !Provider.Modified("dsl")
      Builtins.y2milestone("Writing configuration")

      # Write dialog caption
      caption = _("Saving DSL Configuration")
      steps = 7

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/7
          _("Write configuration"),
          # Progress stage 2/7
          _("Write network card configuration"),
          # Progress stage 3/7
          _("Write firewall settings"),
          # Progress stage 4/7
          _("Write providers"),
          # Progress stage 5/7
          _("Set up network services"),
          # Progress stage 6/7
          _("Set up smpppd"),
          # Progress stage 9
          _("Activate network services")
        ],
        [],
        ""
      )

      # Stop the detection
      NetHwDetection.Stop if NetHwDetection.running

      return false if Abort()
      # Progress step 1/7
      ProgressNextStage(_("Writing configuration..."))
      NetworkInterfaces.Write("dsl")
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 2/7
      ProgressNextStage(_("Writing network card configuration..."))
      progress_orig = Progress.set(false)
      Lan.Write
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 3/7
      ProgressNextStage(_("Writing firewall settings..."))
      progress_orig = Progress.set(false)
      SuSEFirewall4Network.Write
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4/7
      ProgressNextStage(_("Writing providers..."))
      Provider.Write("dsl")
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 5/7
      ProgressNextStage(_("Setting up network services..."))
      NetworkService.EnableDisable
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 6/7
      ProgressNextStage(_("Setting up smpppd(8)..."))
      SetupSMPPPD(true)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 9
      ProgressNextStage(_("Activating network services..."))
      if !@write_only
        #	NetworkModules::HwUp (); // this is needed too
        NetworkService.StartStop
      end
      Builtins.sleep(sl)

      return false if Abort()
      # Final progress step
      ProgressNextStage(_("Finished"))
      Builtins.sleep(sl)

      return false if Abort()
      true
    end

    # Select the given device
    # @param [String] dev device to select ("" for new device, default values)
    # @return true if success
    def Select(dev)
      Builtins.y2debug("dev=%1", dev)
      # defaults for a new device
      devmap = {
        "STARTMODE"   => "manual", # see also #44804
        "USERCONTROL" => "yes"
      }

      # dev=="" -> Add
      if dev == ""
        @type = "dsl"
        @device = Builtins.sformat(
          "dsl%1",
          NetworkInterfaces.GetFreeDevice(@type)
        )
      else
        typ = NetworkInterfaces.device_type(dev)
        num = NetworkInterfaces.device_num(dev)

        NetworkInterfaces.Edit(dev)
        devmap = deep_copy(NetworkInterfaces.Current)
        @type = typ
        @device = Builtins.sformat("%1%2", @type, num)
        @operation = :edit
      end

      # general stuff
      @description = BuildDescription(@type, @device, devmap, @Hardware)
      @unique = Ops.get_string(devmap, "UDI", "")
      @startmode = Ops.get_string(devmap, "STARTMODE", "manual")
      @usercontrol = Ops.get_string(devmap, "USERCONTROL", "no") == "yes"

      # DSL settings
      @vpivci = Ops.get_string(devmap, "VPIVCI", "")
      @modemip = Ops.get_string(devmap, "MODEM_IP", "10.0.0.138")
      @pppmode = Ops.get_string(devmap, "PPPMODE", "")
      @interface = Ops.get_string(devmap, "DEVICE", "")
      @PPPDoptions = Ops.get_string(devmap, "PPPD_OPTIONS", "")

      # provider settings
      Provider.Name = Ops.get_string(devmap, "PROVIDER", "")

      # ppp mode heuristics
      if @pppmode == nil || @pppmode == ""
        country = Provider.GetCountry
        Builtins.y2debug("country=%1", country)

        pppmodes = {
          # pptp removed because we no longer have ppp_mppe.ko, #73043
          # I leave related code in for the case it comes back
          # reenabled on request from aj@suse.de
          "AT" => "pptp",
          "CZ" => "pptp",
          "DE" => "pppoe",
          "GB" => "pppoatm",
          "CA" => "pppoe"
        }
        @pppmode = Ops.get_string(pppmodes, country, "pppoe")
      end

      true
    end

    # Add a new device
    # @return true if success
    def Add
      @operation = nil
      return false if Select("") != true
      NetworkInterfaces.Add
      @operation = :add
      true
    end

    # Edit the given device
    # @param [String] name device to edit
    # @return true if success
    def Edit(name)
      @operation = nil
      return false if Select(name) != true
      NetworkInterfaces.Edit(name)
      @operation = :edit
      true
    end

    # Delete the given device
    # @param [String] name device to delete
    # @return true if success
    def Delete(name)
      @operation = nil
      return false if Select(name) != true
      NetworkInterfaces.Delete(name)
      @operation = :delete
      true
    end

    # Commit the pending operation
    # @return true if success
    def Commit
      Builtins.y2debug("Commit(%1)", @operation)

      if @operation == :add || @operation == :edit
        newdev = {
          "STARTMODE"    => @startmode,
          "USERCONTROL"  => @usercontrol ? "yes" : "no",
          "BOOTPROTO"    => "none",
          "UDI"          => @unique,
          "NAME"         => @description,
          "PPPMODE"      => @pppmode,
          "PROVIDER"     => Provider.Name,
          # "PROVIDER_NAME"	: Provider::Current["PROVIDER"]:"",
          "PPPD_OPTIONS" => @PPPDoptions
        }
        Ops.set(newdev, "DEVICE", @interface)
        Ops.set(newdev, "VPIVCI", @vpivci)
        Ops.set(newdev, "MODEM_IP", @modemip)

        NetworkInterfaces.Name = @device
        NetworkInterfaces.Current = deep_copy(newdev)
        NetworkInterfaces.Commit
      elsif @operation == :delete
        NetworkInterfaces.Commit
      else
        Builtins.y2error("Unknown operation: %1", @operation)
        return false
      end

      @modified = true
      @operation = nil
      true
    end

    # Propose a configuration
    # @return true if something was proposed
    def Propose
      Builtins.y2milestone("Hardware=%1", @Hardware)

      # y2milestone("Devices=%1", Devices);
      #
      # /* Something is already configured -> do nothing * /
      # if(size(Devices) > 0) {
      # 	y2milestone("Something already configured: don't propose.");
      # 	return false;
      # }

      Add()

      true
    end

    # Import data
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = deep_copy(settings)
      NetworkInterfaces.Import("dsl", Ops.get_map(settings, "devices", {}))
      Provider.Import("dsl", Ops.get_map(settings, "providers", {}))
      true
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export
      {
        "devices"   => NetworkInterfaces.Export("dsl"),
        "providers" => Provider.Export("dsl")
      }
    end

    # Create a textual summary and a list of unconfigured devices
    # @param [Boolean] split split configured and unconfigured?
    # @return summary of the current configuration
    def Summary(split)
      sum = BuildSummary("dsl", @Hardware, split, false)
      return deep_copy(sum) if @HWDetected != true

      hwdet = Summary.DevicesList(
        [
          "<li>" +
            # Summary label
            _("Unknown (PPPoE-style) DSL Device Detected") + "</li>"
        ]
      )
      # FIXME: HW

      Builtins.y2milestone("hwdet=%1", @HWDetected)
      Builtins.y2milestone("sum=%1", sum)
      if Ops.get_string(sum, 0, "") == Summary.DevicesList([])
        Ops.set(sum, 0, hwdet)
      else
        Ops.set(sum, 0, Ops.add(Ops.get_string(sum, 0, ""), hwdet))
      end

      deep_copy(sum)
    end

    # Create an overview table with all configured devices
    # @return table items
    def Overview
      res = BuildOverview("dsl", @Hardware)
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

    def Unconfigured
      BuildUnconfigured("dsl", @Hardware)
    end

    # Select the hardware component
    # @param [Fixnum] which index of the component
    def SelectHW(which)
      sel = SelectHardware(@Hardware, which)

      @pppmode = Ops.get_string(sel, "pppmode", "capi-adsl")
      @startmode = Ops.get_string(sel, "startmode", "manual")

      nil
    end

    def Packages
      if Ops.less_than(Builtins.size(NetworkInterfaces.List("dsl")), 1)
        return []
      end
      ["smpppd", "ppp", "pptp", "libatm1"]
    end

    # Return true if the device is used by any DSL connection
    # @param [String] device device to be tested
    # @return true if yes
    def UsesDevice(device)
      Ops.greater_than(
        Builtins.size(NetworkInterfaces.Locate("DEVICE", device)),
        0
      )
    end

    # Used to see whether we are in the process of adding a new interface
    # or editing an existing one.
    # @return adding?
    def Adding
      @operation == :add
    end

    publish :variable => :description, :type => "string"
    publish :variable => :type, :type => "string"
    publish :variable => :device, :type => "string"
    publish :variable => :unique, :type => "string"
    publish :variable => :startmode, :type => "string"
    publish :variable => :usercontrol, :type => "boolean"
    publish :variable => :hotplug, :type => "string"
    publish :variable => :Requires, :type => "list <string>"
    publish :variable => :capiadsl, :type => "map"
    publish :variable => :interface, :type => "string"
    publish :variable => :vpivci, :type => "string"
    publish :variable => :modemip, :type => "string"
    publish :variable => :pppmode, :type => "string"
    publish :variable => :username, :type => "string"
    publish :variable => :password, :type => "string"
    publish :variable => :idletime, :type => "integer"
    publish :variable => :dialondemand, :type => "boolean"
    publish :variable => :dns1, :type => "string"
    publish :variable => :dns2, :type => "string"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :variable => :AbortFunction, :type => "block <boolean>"
    publish :function => :Modified, :type => "boolean ()"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Select, :type => "boolean (string)"
    publish :function => :Add, :type => "boolean ()"
    publish :function => :Edit, :type => "boolean (string)"
    publish :function => :Delete, :type => "boolean (string)"
    publish :function => :Commit, :type => "boolean ()"
    publish :function => :Propose, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "list (boolean)"
    publish :function => :Overview, :type => "list ()"
    publish :function => :Unconfigured, :type => "list <map <string, any>> ()"
    publish :function => :SelectHW, :type => "void (integer)"
    publish :function => :Packages, :type => "list <string> ()"
    publish :function => :UsesDevice, :type => "boolean (string)"
    publish :function => :Adding, :type => "boolean ()"
  end

  DSL = DSLClass.new
  DSL.main
end
