# encoding: utf-8

require 'yast'

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

    # udev rule attribute for MAC address
    MAC_UDEV_ATTR   = "ATTR{address}"

    # udev rule attribute for BUS id
    BUSID_UDEV_ATTR = "KERNELS"

    def initialize

      textdomain "network"

      Yast.include self, "network/routines.rb"

      current_item = LanItems.getCurrentItem

      @old_name = if LanItems.current_renamed?
        LanItems.current_renamed_to
      else
        LanItems.GetItemUdev("NAME")
      end

      @old_key = MAC_UDEV_ATTR unless LanItems.GetItemUdev( MAC_UDEV_ATTR).empty?
      @old_key = BUSID_UDEV_ATTR unless LanItems.GetItemUdev( BUSID_UDEV_ATTR).empty?

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
      new_name = @old_name
      while ![:cancel, :abort, :ok].include? ret
        ret = UI.UserInput

        case ret
          when :ok
            new_name = UI.QueryWidget(:dev_name, :Value)

            if new_name != @old_name
              if CheckUdevNicName(new_name)
                LanItems.rename(new_name)
              else
                UI.SetFocus(:dev_name)
                ret = nil

                next
              end
            else
              LanItems.rename(new_name)
            end

            if UI.QueryWidget(:udev_type, :CurrentButton) == :mac
              rule_key = MAC_UDEV_ATTR
              rule_value = @mac
            else
              rule_key = BUSID_UDEV_ATTR
              rule_value = @bus_id
            end

            # update udev rules and other config
            LanItems.ReplaceItemUdev(@old_key, rule_key, rule_value)
        end
      end

      close

      new_name
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
                #make sure there is enough space (#367239)
                HSpacing(30),
                Left(
                  RadioButton(
                    Id(:mac),
                    _("MAC address: %s") % @mac
                  )
                ),
                Left(
                  RadioButton(
                    Id(:busid),
                    _("BusID: %s") % @bus_id
                  )
                )
              )
            ),
          ),
          VSpacing(0.5),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      case @old_key
        when MAC_UDEV_ATTR
          UI.ChangeWidget(Id(:udev_type), :CurrentButton, :mac)
        when BUSID_UDEV_ATTR
          UI.ChangeWidget(Id(:udev_type), :CurrentButton, :busid)
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
      if UsedNicName(name)
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
