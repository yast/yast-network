#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

module Yast
  extend Yast::I18n

  import "SuSEFirewall4Network"
  import "SuSEFirewallProposal"
  import "WFM"

  describe "FirewallStage1ProposalClient" do
    describe "MakeProposal" do
      before(:each) do
        # Ensure a fixed proposal
        SuSEFirewallProposal.SetChangedByUser(true)
        SuSEFirewall4Network.SetSshEnabled1stStage(true)
      end

      let(:proposal) do
        res = Yast::WFM.CallFunction(
          "firewall_stage1_proposal",
          ["MakeProposal"]
        )
        res["preformatted_proposal"]
      end
      let(:ssh_string) do
        Yast.textdomain "network"
        format(
          Yast._("SSH port will be open (<a href=\"%s\">block</a>)"),
          "firewall--disable_ssh_port_in_proposal"
        )
      end

      context "when firewall is enabled" do
        before { SuSEFirewall4Network.SetEnabled1stStage(true) }

        it "displays ssh port settings" do
          expect(proposal).to include ssh_string
        end
      end

      context "when firewall is disabled" do
        before { SuSEFirewall4Network.SetEnabled1stStage(false) }

        it "hides ssh port settings" do
          expect(proposal).not_to include ssh_string
        end
      end
    end
  end
end
