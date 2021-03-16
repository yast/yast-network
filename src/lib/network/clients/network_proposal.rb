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
      SWITCH_TO_NETWORK_MANAGER = "network--switch-to-nm".freeze
    ].freeze

    VIRT_PROPOSAL_LINKS = [
      PROPOSE_BRIDGE = "network--propose-bridge".freeze,
      PROPOSE_NON_BRIDGE = "network--dont-propose-bridge".freeze
    ].freeze

    def initialize
      Yast.import "UI"
      Yast.import "Lan"

      textdomain "installation"

      settings.refresh_packages
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
      return proposal_summary.text unless settings.network_manager_available?

      proposal_text = switch_backend_link
      proposal_text << toggle_virt_proposal_link if settings.virtual_proposal_required?
      proposal_text.prepend(proposal_summary.text) if wicked_backend?
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
      # TRANSLATORS: text of link for switch to another network backend. %s is the name of backend,
      # example "wicked" or "NetworkManager"
      switch_to = _("switch to %s")

      if wicked_backend?
        current_backend         = "wicked"
        link_to_another_backend = Hyperlink(SWITCH_TO_NETWORK_MANAGER, switch_to % "NetworkManager")
      else
        current_backend         = "NetworkManager"
        link_to_another_backend = Hyperlink(SWITCH_TO_WICKED, switch_to % "wicked")
      end

      "<ul><li>#{backend_in_use % current_backend} (#{link_to_another_backend})</li></ul>"
    end

    def launch_network_configuration(args)
      log.info "Launching network configuration"
      Yast::Wizard.OpenAcceptDialog
      result = Yast::WFM.CallFunction("inst_lan", [args.merge("skip_detection" => true)])
      log.info "Returning from the network configuration with: #{result}"
      result
    ensure
      Yast::Wizard.CloseDialog
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

    def wicked_backend?
      settings.current_backend != :network_manager
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
