require "cwm/dialog"

module Y2Network
  module Dialogs
    # Dialog to manage WEP keys
    class WirelessWepKeys < CWM::Dialog
      # @param builder [Y2network::InterfaceConfigBuilder]
      def initialize(builder)
        textdomain "network"
        @builder = builder
      end

      def title
        _("Wireless Keys")
      end

      def help
        _(
          "<p>In this dialog, define your WEP keys used\n" \
            "to encrypt your data before it is transmitted. You can have up to four keys,\n" \
            "although only one key is used to encrypt the data. This is the default key.\n" \
            "The other keys can be used to decrypt data. Usually you have only\n" \
            "one key.</p>"
        )
      end

      def contents
        HBox(
          HSpacing(5),
          VBox(
            VSpacing(1),
            # Frame label
            Frame(
              _("WEP Keys"),
              HBox(
                HSpacing(3),
                VBox(
                  VSpacing(1),
                  # ComboBox label
                  Left(WEPKeyLength.new(@builder)),
                  VSpacing(1),
                  WEPKeys.new(@builder),
                  VSpacing(1)
                ),
                HSpacing(3)
              )
            ),
            VSpacing(1)
          ),
          HSpacing(5)
        )
      end

      # Always open new dialog to work properly in sequence
      def should_open_dialog?
        true
      end

      class WEPKeyLength < CWM::ComboBox
        def initialize(builder)
          textdomain "network"

          @builder = builder
        end

        def items
          [
            ["64", "64"],
            ["128", "128"]
          ]
        end

        def init
          length_s = @builder.key_length.to_s
          self.value = length_s.empty? ? "128" : length_s
        end

        def store
          @builder.key_length = value.to_i
        end

        def label
          _("&Key Length")
        end

        def help
          _(
            "<p><b>Key Length</b> defines the bit length of your WEP keys.\n" \
              "Possible are 64 and 128 bit, sometimes also referred to as 40 and 104 bit.\n" \
              "Some older hardware might not be able to handle 128 bit keys, so if your\n" \
              "wireless LAN connection does not establish, you may need to set this\n" \
              "value to 64.</p>"
          )
        end
      end

      class WEPKeys < CWM::CustomWidget
        def initialize(settings)
          textdomain "network"
          @settings = settings
        end

        def contents
          VBox(
            Table(
              Id(:wep_keys_table),
              Header(
                # Table header label
                # Abbreviation of Number
                _("No."),
                # Table header label
                _("Key"),
                # Table header label
                Center(_("Default"))
              )
            ),
            HBox(
              # PushButton label
              PushButton(Id(:wep_keys_add), Yast::Label.AddButton),
              # PushButton label
              PushButton(Id(:wep_keys_edit), Yast::Label.EditButton),
              # PushButton label
              PushButton(Id(:wep_keys_delete), Yast::Label.DeleteButton),
              # PushButton label
              PushButton(Id(:wep_keys_default), _("&Set as Default"))
            )
          )
        end

        # TODO: help text which explain format of WEP keys

        def init
          refresh_table
        end

        def refresh_table
          table_items = @settings.keys.each_with_index.map do |key, i|
            next unless key
            Item(Id(i), i.to_s, key, i == @settings.default_key ? "X" : "")
          end

          Yast::UI.ChangeWidget(Id(:wep_keys_table), :Items, table_items.compact)
          [:wep_keys_delete, :wep_keys_edit, :wep_keys_default].each do |k|
            Yast::UI.ChangeWidget(
              Id(k),
              :Enabled,
              !@settings.keys.compact.empty?
            )
          end
          Yast::UI.ChangeWidget(
            Id(:wep_keys_add),
            :Enabled,
            @settings.keys.compact.size < 4 # only 4 keys are possible
          )
        end

        # @return [Symbol, nil] dialog result
        def handle(event)
          return nil if event["EventReason"] != "Activated"

          cur = Yast::UI.QueryWidget(Id(:wep_keys_table), :CurrentItem).to_i
          case event["ID"]
          when :wep_keys_edit
            key = dialog(@settings.keys[cur])
            if key
              @settings.keys[cur] = key
              refresh_table
              Yast::UI.ChangeWidget(Id(:wep_keys_table), :CurrentItem, cur)
            end
          when :wep_keys_add
            key = dialog
            if key
              # replace first nil value
              index = @settings.keys.index(nil)
              if index
                @settings.keys[index] = key
              else
                @settings.keys << key
              end
              log.info "new keys #{@settings.keys.inspect}"
              refresh_table
              Yast::UI.ChangeWidget(
                Id(:wep_keys_table),
                :CurrentItem,
                @settings.keys.compact.size - 1
              )
            end
          when :wep_keys_delete
            @settings.keys.delete_at(cur)
            refresh_table
          when :wep_keys_default
            @settings.default_key = cur
            refresh_table
            Yast::UI.ChangeWidget(Id(:wep_keys_table), :CurrentItem, cur)
          end

          nil
        end

        # Open a dialog to add/edit a key.
        # TODO: own class for it
        # @param value  [String, nil] existing key to edit or nil for new key.
        # @return      [String, nil] key or nil if dialog is canceled
        def dialog(value = nil)
          value ||= ""
          Yast::UI.OpenDialog(
            Opt(:decorated),
            VBox(
              HSpacing(1),
              # TextEntry label
              TextEntry(Id(:key), _("&WEP Key"), value),
              HSpacing(1),
              HBox(
                PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
                PushButton(Id(:cancel), Yast::Label.CancelButton)
              )
            )
          )

          Yast::UI.SetFocus(Id(:key))
          val = nil
          while (ret = Yast::UI.UserInput) == :ok
            val = Yast::UI.QueryWidget(Id(:key), :Value)
            if !valid_key(val)
              # Popup::Error text
              Yast::Popup.Error(
                _(
                  "The WEP key is not valid. WEP key can be specified either directly in hex " \
                    "digits, with or without dashes, or in the key's ASCII representation " \
                    "(prefix s: ), or as a passphrase which will be hashed (prefix h: )."
                )
              )
              next
            end
            break
          end

          Yast::UI.CloseDialog
          return nil if ret != :ok

          val
        end

        def valid_key(_key)
          # TODO: write validation
          true
        end
      end
    end
  end
end
