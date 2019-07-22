require "cwm/dialog"
require "y2network/widgets/interface_type"
require "y2network/interface_config_builder"

Yast.import "Label"
Yast.import "LanItems"
Yast.import "NetworkInterfaces"

module Y2Network
  module Dialogs
    # Dialog which starts new device creation
    class AddInterface < CWM::Dialog
      def initialize(default: nil)
        @type_widget = Widgets::InterfaceType.new(default: default ? default.short_name : nil)
      end

      def contents
        HBox(
          @type_widget
        )
      end

      # initialize legacy stuff, that should be removed soon
      def legacy_init
        # FIXME: can be mostly deleted
        Yast::LanItems.AddNew
        # FIXME: can be partly deleted and partly moved
        Yast::Lan.Add

        # FIXME: This is for backward compatibility only
        # dhclient needs to set just one dhcp enabled interface to
        # DHCLIENT_SET_DEFAULT_ROUTE=yes. Otherwise interface is selected more
        # or less randomly (bnc#868187). However, UI is not ready for such change yet.
        # As it could easily happen that all interfaces are set to "no" (and
        # default route is unreachable in such case) this explicit setup was
        # added.
        # FIXME: not implemented in network-ng
        Yast::LanItems.set_default_route = true
      end

      # @return [Y2Network::InterfaceConfigBuilder, nil] returns new builder when type selected or nil if canceled
      def run
        legacy_init

        ret = super
        log.info "AddInterface result #{ret}"
        ret = :back if ret == :abort

        # TODO: replace with builder initialization
        if ret == :back
          Yast::LanItems.Rollback
          return nil
        end

        # TODO: use factory to get proper builder
        builder = InterfaceConfigBuilder.for(InterfaceType.from_short_name(@type_widget.result))
        proposed_name = Yast::LanItems.new_type_devices(@type_widget.result, 1).first
        builder.name = proposed_name
        Yast::NetworkInterfaces.Name = proposed_name
        Yast::LanItems.Items[Yast::LanItems.current]["ifcfg"] = proposed_name
        Yast::LanItems.Items[Yast::LanItems.current]["udev"] = {}

        builder
      end

      # no back button for add dialog
      def back_button
        ""
      end

      # as it is a sub dialog it can only cancel and cannot abort
      def abort_button
        Yast::Label.CancelButton
      end

      # always open new dialog
      def should_open_dialog?
        true
      end
    end
  end
end
