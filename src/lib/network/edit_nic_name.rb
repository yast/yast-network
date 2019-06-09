# encoding: utf-8

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
    attr_accessor :old_name
    # @return [String] current udev match criteria
    attr_accessor :old_key

    # udev rule attribute for MAC address
    MAC_UDEV_ATTR   = "ATTR{address}".freeze

    # udev rule attribute for BUS id
    BUSID_UDEV_ATTR = "KERNELS".freeze

    def initialize
      textdomain "network"

      Yast.include self, "network/routines.rb"

      current_item = LanItems.getCurrentItem
      current_rule = LanItems.current_udev_rule

      @old_name = LanItems.current_udev_name
      unless current_rule.empty?
        @old_key = :mac unless LanItems.GetItemUdev(MAC_UDEV_ATTR).empty?
        @old_key = :bus_id unless LanItems.GetItemUdev(BUSID_UDEV_ATTR).empty?
      end

      if current_item["hwinfo"]
        @mac = current_item["hwinfo"]["mac"]
        @bus_id = current_item["hwinfo"]["busid"]
      else
        @mac = ""
        @bus_id = ""
      end
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

        if CheckUdevNicName(new_name)
          LanItems.rename(new_name)
        else
          UI.SetFocus(:dev_name)
          ret = nil

          next
        end

        udev_type = UI.QueryWidget(:udev_type, :CurrentButton)

        # FIXME: it changes udev key used for device identification
        #  and / or its value only, name is changed elsewhere
        LanItems.update_item_udev_rule!(udev_type) if udev_type && (old_key != udev_type)
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
              InputField(Id(:dev_name), Opt(:hstretch), "", @old_name)
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
      if LanItems.GetNetcardNames.include?(name) && name != LanItems.GetCurrentName
        Popup.Error(_("Configuration name already exists."))
        return false
      end
      if !ValidNicName(name)
        Popup.Error(_("Invalid configuration name."))
        return false
      end

      true
    end
  end
end
