# Copyright (c) [2019] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"

module Yast
  Yast.import "UI"
  Yast.import "LanItems"
  Yast.import "Popup"

  # The class represents a simple dialog which allows user to input new NIC
  # name. It also allows to select a device attribute (MAC, Bus id, ...) which will
  # be used for device selection.
  class EditNicName
    include UIShortcuts
    include I18n

    # @return [String] current udev name before modifying it
    attr_reader :old_name
    # @return [String] current udev match criteria
    attr_reader :old_key

    # Constructor
    #
    # @param settings [Y2Network::InterfaceConfigBuilder] Interface configuration
    def initialize(settings)
      textdomain "network"
      @settings = settings
      interface = settings.interface
      @old_name = interface.name
      @old_key = interface.renaming_mechanism
      @mac = interface.hardware.mac
      @bus_id = interface.hardware.busid
    end

    # Opens dialog for editing NIC name and runs event loop.
    #
    # @return [String] new NIC name
    def run
      open

      ret = nil
      until [:cancel, :abort, :ok].include? ret
        ret = UI.UserInput

        next if ret != :ok

        new_name = UI.QueryWidget(:dev_name, :Value)
        udev_type = UI.QueryWidget(:udev_type, :CurrentButton)

        if CheckUdevNicName(new_name)
          @settings.rename_interface(new_name, udev_type)
        else
          UI.SetFocus(:dev_name)
          ret = nil

          next
        end
      end

      close

      new_name || old_name
    end

  private

    # Opens dialog for editing NIC name
    def open
      UI.OpenDialog(
        VBox(
          Left(
            HBox(
              Label(_("Device Name:")),
              InputField(Id(:dev_name), Opt(:hstretch), "", old_name)
            )
          ),
          VSpacing(0.5),
          Frame(
            _("Base Udev Rule On"),
            RadioButtonGroup(
              Id(:udev_type),
              VBox(
                # make sure there is enough space (#367239)
                HSpacing(30),
                Left(
                  RadioButton(
                    Id(:mac),
                    _("MAC address: %s") % @mac
                  )
                ),
                Left(
                  RadioButton(
                    Id(:bus_id),
                    _("BusID: %s") % @bus_id
                  )
                )
              )
            )
          ),
          VSpacing(0.5),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      if old_key
        UI.ChangeWidget(Id(:udev_type), :CurrentButton, old_key)
      else
        Builtins.y2error("Unknown udev rule.")
      end
    end

    # Closes the dialog
    def close
      UI.CloseDialog
    end

    # Checks if given name can be accepted as nic's new one.
    #
    # Pops up an explanation if the name is invalid
    #
    # @return [boolean] false if name is invalid
    def CheckUdevNicName(name)
      # check if the name is assigned to another device already
      if @settings.name_exists?(name)
        Popup.Error(_("Configuration name already exists."))
        return false
      end

      if !@settings.valid_name?(name)
        Popup.Error(_("Invalid configuration name."))
        return false
      end

      true
    end

    # When an interface name has changed, it returns whether the user wants to
    # update the interface name in the related routes or not.
    #
    # return [Boolean] whether the routes have to be updated or not
    def update_routes?(previous_name)
      return false unless Routing.device_routes?(previous_name)

      Popup.YesNoHeadline(
        Label.WarningMsg,
        # TRANSLATORS: Ask for fixing a possible conflict after renaming
        # an interface, %s are the previous and current interface names
        format(_("The interface %s has been renamed to %s. There are \n" \
                  "some routes that still use the previous name.\n\n" \
                  "Would you like to update them now?\n"),
          "'#{previous_name}'",
          "'#{LanItems.current_name}'")
      )
    end
  end
end
