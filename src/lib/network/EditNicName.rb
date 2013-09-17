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
        # current item is cruicial 
        return nil if current_item.nil?

        # no mac/busid in hwinfo
        @mac = "" if mac.nil?
        @bus_id = "" if bus_id.nil?
      end
    end

    def run
      open

      ret = nil
      while ret != :cancel && ret != :abort && ret != :ok
        ret = UI.UserInput
        change_name_active = Convert.to_boolean(
          UI.QueryWidget(:change_dev_name, :Value)
        )

        if ret == :change_dev_name
          UI.ChangeWidget(:dev_name, :Enabled, change_name_active)
        end

        if ret == :ok
          new_name = Convert.to_string(UI.QueryWidget(:dev_name, :Value))

          break if !change_name_active || new_name == @old_name

          if !CheckUdevNicName(new_name)
            UI.SetFocus(:dev_name)
            ret = nil

            next
          end

          if UI.QueryWidget(:udev_type, :CurrentButton) == :mac 
            rule_key = MAC_UDEV_ATTR
            rule_value = @mac
          else
            rule_key = BUSID_UDEV_ATTR
            rule_value = @bus_id
          end

          # update udev rules and other config
          LanItems.SetCurrentName( new_name)
          LanItems.ReplaceItemUdev( @old_key, rule_key, rule_value)
        end
      end

      close

      LanItems.GetCurrentName
    end

    protected
    def open
      UI.OpenDialog(
        VBox(
          RadioButtonGroup(
            Id(:udev_type),
            VBox(
              #make sure there is enough space (#367239)
              HSpacing(30),
              Label(_("Rule by:")),
              Left(
                RadioButton(
                  Id(:mac),
                  "MAC address: #{@mac}"
                )
              ),
              Left(
                RadioButton(
                  Id(:busid),
                  "BusID: #{@bus_id}"
                )
              )
            )
          ),
          Left(
            HBox(
              CheckBox(
                Id(:change_dev_name),
                Opt(:notify),
                _("Change DeviceName"),
                false
              ),
              InputField(Id(:dev_name), "", @old_name)
            )
          ),
          VSpacing(0.5),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      if @old_key == MAC_UDEV_ATTR
        UI.ChangeWidget(Id(:udev_type), :CurrentButton, :mac)
      elsif @old_key == BUSID_UDEV_ATTR
        UI.ChangeWidget(Id(:udev_type), :CurrentButton, :busid)
      else
        Builtins.y2error("Unknown udev rule ")
      end

      UI.ChangeWidget(:dev_name, :Enabled, false)
    end
  
    protected
    def close
      UI.CloseDialog
    end

    # Checks if given name can be accepted as nic's new one.
    #
    # @return false and pops up an explanation if the name is invalid
    protected
    def CheckUdevNicName(name)
      # when dev_name changed, rename ifcfg (both in NetworkInterfaces and LanItems)
      error = false

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
