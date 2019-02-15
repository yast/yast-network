require "cgi"
require "installation/proposal_client"
require "y2network/proposal_settings"

module Yast
  # Proposal client for Network configuration
  class NetworkProposal < ::Installation::ProposalClient
    include Yast::I18n
    include Yast::Logger

    BACKEND_LINKS = [
      SWITCH_TO_WICKED = "network--switch-to-wicked".freeze,
      SWITCH_TO_NETWORK_MANAGER = "network--switch-to-nm".freeze
    ].freeze

    def initialize
      Yast.import "UI"
      Yast.import "Lan"
      Yast.import "LanItems"

      textdomain "installation"
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
        "label_proposal"        => [Yast::LanItems.summary("one_line")],
        "links"                 => BACKEND_LINKS
      }
    end

    def ask_user(args)
      result =
        case args["chosen_id"]
        when "network--switch-to-wicked"
          switch_to_wicked
        when "network--switch-to-nm"
          switch_to_network_manager
        else
          launch_network_configuration(args)
        end

      { "workflow_sequence" => result }
    end

  private

    def preformatted_proposal
      proposal_text = switch_backend_link
      proposal_text.prepend(Yast::Lan.Summary("proposal")) if wicked_backend?
      proposal_text
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

    def switch_to_wicked
      settings.enable_wicked!
      :next
    end

    def switch_to_network_manager
      settings.enable_network_manager!
      :next
    end

    def wicked_backend?
      settings.backend != :network_manager
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
