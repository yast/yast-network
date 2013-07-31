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
# File:	modules/Modem.ycp
# Package:	Network configuration
# Summary:	Modem data
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Representation of the configuration of modem.
# Input and output routines.
require "yast"

module Yast
  class ModemClass < Module
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "NetworkInterfaces"
      Yast.import "NetworkService"
      Yast.import "Provider"
      Yast.import "Progress"
      Yast.import "Routing"
      Yast.import "Service"
      Yast.import "Summary"
      Yast.import "Message"
      Yast.import "SuSEFirewall4Network"

      Yast.include self, "network/complex.rb"

      # general stuff
      @description = ""
      @type = ""
      @device = ""
      @unique = ""
      @startmode = "manual"
      @usercontrol = false
      @Requires = []

      # Hotplug type ("" if not hot pluggable)
      @hotplug = ""

      # modem settings
      @Init1 = "ATZ"
      @Init2 = "AT Q0 V1 E1 S0=0 &C1 &D2 +FCLASS=0"
      @Init3 = ""
      @BaudRate = 57600

      @PulseDial = true
      @Carrier = true
      @Speaker = true

      @Device = "/dev/modem"
      @DialPrefix = ""
      @DialPrefixRx = ""
      @PPPDoptions = ""

      # something already proposed?
      @proposal_valid = false

      #--------------
      # PRIVATE DATA

      # Hardware information
      # @see #ReadHardware
      @Hardware = []

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
      # Read dialog caption
      caption = _("Initializing Modem Configuration")
      steps = 5

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/4
          _("Detect modems"),
          # Progress stage 2/4
          _("Read current configuration"),
          # Progress stage 3/4
          _("Read firewall settings"),
          # Progress stage 4/4
          _("Read providers"),
          # Progress stage 5/5
          _("Read routing")
        ],
        [],
        ""
      )

      return false if Abort()

      # check the environment
      return false if !Confirm.MustBeRoot


      # Progress step 1/4
      ProgressNextStage(_("Detecting modems..."))
      @Hardware = ReadHardware("modem")
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 2/4
      ProgressNextStage(_("Reading current configuration..."))
      NetworkInterfaces.Read
      NetworkService.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 3/4
      ProgressNextStage(_("Reading firewall settings..."))
      progress_orig = Progress.set(false)
      SuSEFirewall4Network.Read
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4/4
      ProgressNextStage(_("Reading providers..."))
      Provider.Read
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4/4
      ProgressNextStage(_("Reading routes..."))
      Routing.Read if !@proposal_valid
      Builtins.sleep(sl)

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
      return true if !@modified && !Provider.Modified("modem")
      Builtins.y2milestone("Writing configuration")

      # Write dialog caption
      caption = _("Saving Modem Configuration")
      steps = 6

      sl = 0 # 1000; /* TESTING
      Builtins.sleep(sl)

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/6
          _("Write configuration"),
          # Progress stage 2/6
          _("Write firewall settings"),
          # Progress stage 3/6
          _("Write providers"),
          # Progress stage 4/6
          _("Set up network services"),
          # Progress stage 5/5
          _("Set up smpppd"),
          # Progress stage 9
          _("Activate network services")
        ],
        [],
        ""
      )

      return false if Abort()
      # Progress step 1/6
      ProgressNextStage(_("Writing configuration..."))
      NetworkInterfaces.Write("modem")
      NetworkInterfaces.UpdateModemSymlink
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 2/6
      ProgressNextStage(_("Writing firewall settings..."))
      progress_orig = Progress.set(false)
      SuSEFirewall4Network.Write
      Progress.set(progress_orig)
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 3/6
      ProgressNextStage(_("Writing providers..."))
      Provider.Write("modem")
      Builtins.sleep(sl)

      return false if Abort()
      # Progress step 4/6
      ProgressNextStage(_("Setting up network services..."))
      NetworkService.EnableDisable
      Builtins.sleep(sl)

      # Setup SL modem
      if Builtins.contains(@Requires, "smartlink-softmodem")
        if !PackageSystem.CheckAndInstallPackages(@Requires)
          Popup.Error(
            Builtins.sformat(
              "%1 : smartlink-softmodem",
              Message.CannotContinueWithoutPackagesInstalled
            )
          )
        end
        Builtins.y2milestone("Setting up smartlink-softmodem ...")

        Service.Stop("slmodemd")

        country = Provider.GetCountry
        keys = Convert.to_map(
          Builtins.eval(SCR.Read(path(".target.yast2"), "modem-t35-keys.ycp"))
        )
        country = Ops.get_string(keys, country, "")

        Builtins.y2milestone("Setting up slmodemd (%1)", country)
        if country != nil && country != ""
          SCR.Write(
            path(".sysconfig.slmodemd.SLMODEMD_COUNTRY"),
            Builtins.toupper(country)
          )
          SCR.Write(path(".sysconfig.slmodemd"), nil)
        end

        Service.Enable("slmodemd")
        Service.Start("slmodemd")
      end

      return false if Abort()
      # Progress step 5/6
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
      devmap = { "USERCONTROL" => "yes" }

      # dev=="" -> Add
      if dev == ""
        @type = "modem"
        @device = Builtins.sformat(
          "modem%1",
          NetworkInterfaces.GetFreeDevice(@type)
        )
      else
        typ = NetworkInterfaces.device_type(dev)
        num = NetworkInterfaces.device_num(dev)

        NetworkInterfaces.Edit(dev)
        devmap = deep_copy(NetworkInterfaces.Current)

        @type = typ
        @device = Builtins.sformat("%1%2", @type, num) 
        # FIXME: why is this here? operation = `edit;
      end

      # general stuff
      @description = BuildDescription(@type, @device, devmap, @Hardware)
      @unique = Ops.get_string(devmap, "UDI", "")
      @startmode = Ops.get_string(devmap, "STARTMODE", "manual")
      @usercontrol = Ops.get_string(devmap, "USERCONTROL", "no") == "yes"

      # modem settings
      @Init1 = Ops.get_string(devmap, "INIT1", "ATZ")
      @Init2 = Ops.get_string(
        devmap,
        "INIT2",
        "AT Q0 V1 E1 S0=0 &C1 &D2 +FCLASS=0"
      )
      @Init3 = Ops.get_string(devmap, "INIT3", "")
      @BaudRate = Builtins.tointeger(Ops.get_string(devmap, "SPEED", "57600"))

      # PulseDial = devmap["DIALCOMMAND"]:"ATDT" == "ATDP";
      # better heuristics:
      @PulseDial = Builtins.filterchars(
        Ops.get_string(devmap, "DIALCOMMAND", "ATDT"),
        "P"
      ) == "P"
      @Speaker = Ops.get_string(devmap, "INIT8", "ATM1") == "ATM1"
      @Carrier = Ops.get_string(devmap, "INIT9", "") == ""

      @Device = Ops.get_string(devmap, "MODEM_DEVICE", "/dev/modem")
      @DialPrefix = Ops.get_string(devmap, "DIALPREFIX", "")
      @DialPrefixRx = Ops.get_string(devmap, "DIALPREFIXREGEX", "")
      @PPPDoptions = Ops.get_string(devmap, "PPPD_OPTIONS", "")

      # provider settings
      Provider.Name = Ops.get_string(devmap, "PROVIDER", "")

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
          "STARTMODE"       => @startmode,
          "USERCONTROL"     => @usercontrol ? "yes" : "no",
          "BOOTPROTO"       => "none",
          "UDI"             => @unique,
          "NAME"            => @description,
          "INIT1"           => @Init1,
          "INIT2"           => @Init2,
          "INIT3"           => @Init3,
          "SPEED"           => Builtins.sformat("%1", @BaudRate),
          "INIT8"           => @Speaker ? "ATM1" : "ATM0",
          "INIT9"           => @Carrier ? "" : "ATX3",
          "DIALCOMMAND"     => @PulseDial ? "ATDP" : "ATDT",
          "MODEM_DEVICE"    => @Device,
          "DIALPREFIX"      => @DialPrefix,
          "DIALPREFIXREGEX" => @DialPrefixRx,
          "PROVIDER"        => Provider.Name,
          # "PROVIDER_NAME"	: Provider::Current["PROVIDER"]:"",
          "PPPD_OPTIONS"    => @PPPDoptions
        }
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

    # Import data
    # @param [Hash] settings settings to be imported
    # @return true on success
    def Import(settings)
      settings = deep_copy(settings)
      NetworkInterfaces.Import("modem", Ops.get_map(settings, "devices", {}))
      Provider.Import("modem", Ops.get_map(settings, "providers", {}))
      true
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export
      {
        "devices"   => NetworkInterfaces.Export("modem"),
        "providers" => Provider.Export("modem")
      }
    end

    # Create a textual summary and a list of unconfigured devices
    # @param [Boolean] split split configured and unconfigured?
    # @return summary of the current configuration
    def Summary(split)
      BuildSummary("modem", @Hardware, split, false)
    end

    # Create an overview table with all configured devices
    # @return table items
    def Overview
      res = BuildOverview("modem", @Hardware)
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
      BuildUnconfigured("modem", @Hardware)
    end

    # Select the hardware component
    # @param [Fixnum] which index of the component
    def SelectHW(which)
      sel = SelectHardware(@Hardware, which)

      @Init1 = Ops.get_string(sel, "init1", "")
      @Init2 = Ops.get_string(sel, "init2", "")
      @Device = Ops.get_string(sel, "device_name", "")
      @BaudRate = Ops.get_integer(sel, "speed", 57600)
      @PPPDoptions = Ops.get_string(sel, "pppd_options", "")
      @type = "modem"

      nil
    end

    def Packages
      if Ops.less_than(Builtins.size(NetworkInterfaces.List("modem")), 1)
        return []
      end
      ["smpppd"]
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
    publish :variable => :Requires, :type => "list <string>"
    publish :variable => :hotplug, :type => "string"
    publish :variable => :Init1, :type => "string"
    publish :variable => :Init2, :type => "string"
    publish :variable => :Init3, :type => "string"
    publish :variable => :BaudRate, :type => "integer"
    publish :variable => :PulseDial, :type => "boolean"
    publish :variable => :Carrier, :type => "boolean"
    publish :variable => :Speaker, :type => "boolean"
    publish :variable => :Device, :type => "string"
    publish :variable => :DialPrefix, :type => "string"
    publish :variable => :DialPrefixRx, :type => "string"
    publish :variable => :PPPDoptions, :type => "string"
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
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "list (boolean)"
    publish :function => :Overview, :type => "list ()"
    publish :function => :Unconfigured, :type => "list <map <string, any>> ()"
    publish :function => :SelectHW, :type => "void (integer)"
    publish :function => :Packages, :type => "list <string> ()"
    publish :function => :Adding, :type => "boolean ()"
  end

  Modem = ModemClass.new
  Modem.main
end
