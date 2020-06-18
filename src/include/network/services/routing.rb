# ***************************************************************************
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
# **************************************************************************
# File:  include/network/services/routing.ycp
# Package:  Network configuration
# Summary:  Routing configuration dialogs
# Authors:  Michal Svec <msvec@suse.cz>
#
#
# Routing configuration dialogs

require "y2network/dialogs/route"
require "y2network/routing_table"
require "y2network/widgets/routing_table"
require "y2network/widgets/routing_buttons"
require "y2network/widgets/ip4_forwarding"
require "y2network/widgets/ip6_forwarding"

module Yast
  module NetworkServicesRoutingInclude
    include Yast::I18n
    include Yast::UIShortcuts
    include Yast::Logger

    def initialize_network_services_routing(_include_target)
      textdomain "network"

      Yast.import "Label"
      Yast.import "Wizard"
      Yast.import "CWM"
      Yast.import "Lan"
    end

    def route_td
      {
        "route" => {
          "header"       => _("Routing"),
          "contents"     => content,
          "widget_names" => widgets.keys
        }
      }
    end

    # TODO: just for CWM fallback function
    def ReallyAbort
      Popup.ReallyAbort(true)
    end

    # Main routing dialog
    # @return dialog result
    def RoutingMainDialog
      caption = _("Routing Configuration")

      functions = {
        abort: Yast::FunRef.new(method(:ReallyAbort), "boolean ()")
      }

      Wizard.HideBackButton

      CWM.ShowAndRun(
        "widget_descr"       => widgets,
        "contents"           => content,
        "caption"            => caption,
        "back_button"        => Label.BackButton,
        "next_button"        => Label.NextButton,
        "fallback_functions" => functions
      )
    end

  private

    def config
      # TODO: get it from some config holder
      @config ||= Yast::Lan.yast_config
    end

    def routing_table_widget
      @routing_table_widget ||= Y2Network::Widgets::RoutingTable.new(config.routing.tables.first)
    end

    def ip4_forwarding_widget
      @ip4_forwarding_widget ||= Y2Network::Widgets::IP4Forwarding.new(config)
    end

    def ip6_forwarding_widget
      @ip6_forwarding_widget ||= Y2Network::Widgets::IP6Forwarding.new(config)
    end

    def add_button
      @add_button ||= Y2Network::Widgets::AddRoute.new(routing_table_widget, config)
    end

    def edit_button
      @edit_button ||= Y2Network::Widgets::EditRoute.new(routing_table_widget, config)
    end

    def delete_button
      @delete_button ||= Y2Network::Widgets::DeleteRoute.new(routing_table_widget)
    end

    def content
      VBox(
        Left(ip4_forwarding_widget.widget_id),
        Left(ip6_forwarding_widget.widget_id),
        VSpacing(),
        # Frame label
        Frame(
          _("Routing Table"),
          VBox(
            routing_table_widget.widget_id,
            HBox(
              add_button.widget_id,
              edit_button.widget_id,
              delete_button.widget_id
            )
          )
        )
      )
    end

    def widgets
      {
        routing_table_widget.widget_id  => routing_table_widget.cwm_definition,
        ip4_forwarding_widget.widget_id => ip4_forwarding_widget.cwm_definition,
        ip6_forwarding_widget.widget_id => ip6_forwarding_widget.cwm_definition,
        add_button.widget_id            => add_button.cwm_definition,
        edit_button.widget_id           => edit_button.cwm_definition,
        delete_button.widget_id         => delete_button.cwm_definition
      }
    end
  end
end
