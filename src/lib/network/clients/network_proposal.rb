require "installation/proposal_client"

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
      if wicked_backend?
        info     = _("Using Wicked")
        switcher = Hyperlink(SWITCH_TO_NETWORK_MANAGER, _("switch to Network Manager"))
      else
        info     = _("Using Network Manager")
        switcher = Hyperlink(SWITCH_TO_WICKED, _("switch to Wicked"))
      end

      "<ul><li>#{info} (#{switcher})</li></ul>"
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
      Yast::NetworkService.use_wicked

      :next
    end

    def switch_to_network_manager
      Yast::NetworkService.use_network_manager

      :next
    end

    def wicked_backend?
      Yast::NetworkService.wicked?
    end

    # TODO: move to HTML.ycp
    def Hyperlink(href, text)
      Builtins.sformat("<a href=\"%1\">%2</a>", href, text)
    end
  end
end
