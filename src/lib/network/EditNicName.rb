# encoding: utf-8

require 'yast'

module Yast

  Yast.import "UI"
  Yast.import "LanItems"
  Yast.import "Popup"

  class EditNicName

    include UIShortcuts
    include I18n
    
    MAC_UDEV_ATTR   = "ATTR{address}"
    BUSID_UDEV_ATTR = "KERNELS"

    def initialize

      textdomain "network"

      Yast.include self, "network/routines.rb"

      current_item = LanItems.getCurrentItem

      @old_name = LanItems.GetItemUdev("NAME")

      @old_key = MAC_UDEV_ATTR unless LanItems.GetItemUdev( MAC_UDEV_ATTR).empty?
      @old_key = BUSID_UDEV_ATTR unless LanItems.GetItemUdev( BUSID_UDEV_ATTR).empty?

      begin
        if current_item[ "hwinfo"]
          @mac = current_item[ "hwinfo"][ "mac"]
          @bus_id = current_item[ "hwinfo"][ "busid"]
        else
          @mac = ""
          @bus_id = ""
        end

      rescue NoMethodError
        Popup.Error(_("Internal error. Please report a bug."))
        Bultins.y2internal( "EditNicName.initialize: current item has to be defined")
 
        # current item is cruicial 
        return nil if current_item.nil?
      end
    end

    def run
      open

      ret = nil
      while ![:cancel, :abort, :ok].include? ret
        ret = UI.UserInput

        case ret
          when :ok
            new_name = UI.QueryWidget(:dev_name, :Value)

            if new_name != @old_name
              if CheckUdevNicName(new_name)
                LanItems.SetCurrentName( new_name)
              else
                UI.SetFocus(:dev_name)
                ret = nil

                next
              end
            end

            if UI.QueryWidget(:udev_type, :CurrentButton) == :mac 
              rule_key = MAC_UDEV_ATTR
              rule_value = @mac
            else
              rule_key = BUSID_UDEV_ATTR
              rule_value = @bus_id
            end

            # update udev rules and other config
            LanItems.ReplaceItemUdev( @old_key, rule_key, rule_value)
        end
      end

      close

      LanItems.GetCurrentName
    end

  private
    # Opens dialog for editing NIC name
    def open
      UI.OpenDialog(
        VBox(
          Left(
            HBox(
              Label( _( "Device name:") ),
              InputField(Id(:dev_name), "", @old_name)
            )
          ),
          VSpacing(0.5),
          Frame(
            _( "Base udev rule on"),
            RadioButtonGroup(
              Id(:udev_type),
              VBox(
                #make sure there is enough space (#367239)
                HSpacing(30),
                Left(
                  RadioButton(
                    Id(:mac),
                    _( "MAC address: %s") % @mac
                  )
                ),
                Left(
                  RadioButton(
                    Id(:busid),
                    _( "BusID: %s") % @bus_id
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
          Builtins.y2error("Unknown udev rule ")
      end
    end
  
    # Closes the dialog
    def close
      UI.CloseDialog
    end

    # Checks if given name can be accepted as nic's new one.
    #
    # @return false and pops up an explanation if the name is invalid
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
