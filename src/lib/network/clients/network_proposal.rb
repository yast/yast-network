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

require "cgi"
require "installation/proposal_client"
require "y2network/proposal_settings"
require "y2network/presenters/summary"

module Yast
  # Proposal client for Network configuration
  class NetworkProposal < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    BACKEND_LINKS = [
      SWITCH_TO_WICKED = "network--switch-to-wicked".freeze,
      SWITCH_TO_NETWORK_MANAGER = "network--switch-to-nm".freeze,
      DISABLE_SERVICES = "network--disable".freeze
    ].freeze

    VIRT_PROPOSAL_LINKS = [
      PROPOSE_BRIDGE = "network--propose-bridge".freeze,
      PROPOSE_NON_BRIDGE = "network--dont-propose-bridge".freeze
    ].freeze

    def initialize
      super
      Yast.import "UI"
      Yast.import "Lan"

      textdomain "installation"

      settings.refresh_packages
      settings.apply_defaults
    end

    def description
      {
        "rich_text_title" => _("Network Configuration"),
        "menu_title"      => _("Network Configuration"),
        "id"              => "network"
      }
    end

    def make_proposal(_)
      {
        "preformatted_proposal" => preformatted_proposal,
        "label_proposal"        => [proposal_summary.one_line_text],
        "links"                 => BACKEND_LINKS + VIRT_PROPOSAL_LINKS
      }
    end

    def ask_user(args)
      result =
        case args["chosen_id"]
        when "network--switch-to-wicked"
          switch_to_wicked
        when "network--switch-to-nm"
          switch_to_network_manager
        when "network--disable"
          disable_services
        when "network--propose-bridge"
          propose_bridge(true)
        when "network--dont-propose-bridge"
          propose_bridge(false)
        else
          launch_network_configuration(args)
        end

      { "workflow_sequence" => result }
    end

  private

    def config
      Yast::Lan.yast_config
    end

    def proposal_summary
      @proposal_summary ||= Y2Network::Presenters::Summary.for(config, "proposal")
    end

    def preformatted_proposal
      proposal_text = switch_backend_link
      return proposal_text if settings.current_backend == :none

      proposal_text << toggle_virt_proposal_link if settings.virtual_proposal_required?
      proposal_text.prepend(proposal_summary.text)
      proposal_text
    end

    def toggle_virt_proposal_link
      propose = _("Propose bridge configuration for virtual machine network")
      non_propose = _("Use non-bridged configuration")
      use_bridge = _("Use bridged configuration")
      use_non_bridge = _("Use non-bridged configuration")

      text =
        if propose_bridge?
          "#{propose} (#{Hyperlink(PROPOSE_NON_BRIDGE, use_non_bridge)})"
        else
          "#{non_propose} (#{Hyperlink(PROPOSE_BRIDGE, use_bridge)})"
        end

      "<ul><li>#{text}</li></ul>"
    end

    def switch_backend_link
      # TRANSLATORS: information about the network backend in use. %s is the name of backend,
      # example "wicked" or "NetworkManager"
      backend_in_use = _("Using <b>%s</b>")

      case settings.current_backend
      when :wicked
        current_backend = "wicked"
        links = [disable_link]
        links.prepend(network_manager_link) if settings.network_manager_available?
      when :network_manager
        current_backend = "NetworkManager"
        links = [wicked_link, disable_link]
      else
        backend_in_use = "<b>%s</b>"
        current_backend = _("Network Services Disabled")
        links = [wicked_link]
        links.append(network_manager_link) if settings.network_manager_available?
      end

      "<ul><li>#{backend_in_use % current_backend} (#{links.join(", ")})</li></ul>"
    end

    def launch_network_configuration(args)
      log.info "Launching network configuration"
      Yast::Wizard.OpenAcceptDialog
      result = Yast::WFM.CallFunction(
        "inst_lan",
        [args.merge("skip_detection" => true, "hide_abort_button" => true)]
      )
      log.info "Returning from the network configuration with: #{result}"
      result
    ensure
      Yast::Wizard.CloseDialog
    end

    def network_manager_link
      # TRANSLATORS: text of link to switch to another network backend. %s is the name of backend,
      # example "wicked" or "NetworkManager"
      Hyperlink(SWITCH_TO_NETWORK_MANAGER, _("switch to %s") % "NetworkManager")
    end

    def wicked_link
      Hyperlink(SWITCH_TO_WICKED, _("switch to %s") % "wicked")
    end

    def disable_link
      Hyperlink(DISABLE_SERVICES, _("disable services"))
    end

    def propose_bridge?
      settings.propose_bridge?
    end

    def propose_bridge(option)
      settings.propose_bridge!(option)
      :next
    end

    def switch_to_wicked
      settings.enable_wicked!
      :next
    end

    def switch_to_network_manager
      settings.enable_network_manager!
      :next
    end

    def disable_services
      settings.disable_network!
      :next
    end

    def wicked_backend?
      settings.current_backend == :wicked
    end

    # TODO: move to HTML.ycp
    def Hyperlink(href, text)
      Builtins.sformat("<a href=\"%1\">%2</a>", href, CGI.escapeHTML(text))
    end
  end

  def settings
    Y2Network::ProposalSettings.instance
  end
end
