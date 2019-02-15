#!/usr/bin/env rspec
require_relative "test_helper"

require "network/clients/network_proposal"

describe Yast::NetworkProposal do
  Yast.import "LanItems"
  Yast.import "Lan"

  before do
    stub_const("Yast::Wizard", double.as_null_object)
    allow(Yast::LanItems).to receive(:summary).with("one_line").and_return("one_line_summary")
    allow(Yast::Lan).to receive(:Summary).with("proposal").and_return("rich_text_summary")
  end

  describe "#description" do
    it "returns a map with id, menu_title and rich_text_title " do
      expect(subject.description).to include("id", "menu_title", "rich_text_title")
    end
  end

  describe "#make_proposal" do
    let(:settings) { Y2Network::ProposalSettings.create_instance }
    let(:using_wicked) { true }
    let(:proposal) { subject.make_proposal({}) }

    before do
      allow(Yast::Lan).to receive(:UseNetworkManager).and_return(!using_wicked)
      allow(settings).to receive(:network_manager_available?).and_return(true)
    end

    it "returns a hash describing the proposal" do
      expect(proposal).to include("label_proposal", "preformatted_proposal", "links")
    end

    context "when using the wicked backend" do
      it "includes the Yast::Lan proposal summary" do
        expect(proposal["preformatted_proposal"]).to include("rich_text_summary")
      end

      it "includes a link for switch to NetworkManager" do
        expect(proposal["preformatted_proposal"]).to match(/.*href.*NetworkManager.*/)
      end

      it "does not include a link for switch to wicked" do
        expect(proposal["preformatted_proposal"]).to_not match(/.*href.*wicked.*/)
      end
    end

    context "when using the NetworkManager backend" do
      before do
        settings.backend = :network_manager
      end

      let(:using_wicked) { false }

      it "does not include the Yast::Lan proposal summary" do
        expect(proposal["preformatted_proposal"]).to_not include("rich_text_summary")
      end

      it "does not include a link for switch to NetworkManager" do
        expect(proposal["preformatted_proposal"]).to_not match(/.*href.*NetworkManager.*/)
      end

      it "includes a link for switch to wicked" do
        expect(proposal["preformatted_proposal"]).to match(/.*href.*wicked.*/)
      end
    end
  end

  describe "#ask_user" do
    let(:settings) { Y2Network::ProposalSettings.instance }
    let(:chosen_id) { "" }
    let(:args) do
      {
        "chosen_id"      => chosen_id,
        "skip_detection" => false
      }
    end

    before do
      allow(Yast::WFM).to receive(:CallFunction)
        .with("inst_lan", anything)
        .and_return("result")
    end

    it "returns a map with 'workflow_sequence' as the result of the client output" do
      expect(subject.ask_user(args)).to have_key("workflow_sequence")
    end

    context "by default" do
      let(:args) { { "chosen_id" => "network" } }

      it "launchs the inst_lan client forcing the manual configuration" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("inst_lan", [hash_including("skip_detection" => true)])

        subject.ask_user(args)
      end

      it "returns the result of the client output as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to eql("workflow_sequence" => "result")
      end
    end

    context "when 'chosen_id' is 'network--switch-to-wicked'" do
      let(:args) { { "chosen_id" => "network--switch-to-wicked" } }

      it "does not launchs the inst_lan client" do
        expect(Yast::WFM).to_not receive(:CallFuntion).with("inst_lan", anything)
      end

      it "changes the network backend to wicked" do
        expect(settings).to receive(:enable_wicked!)

        subject.ask_user(args)
      end

      it "returns :next as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to include("workflow_sequence" => :next)
      end
    end

    context "when 'chosen_id' is 'network--switch-to-wicked'" do
      let(:args) { { "chosen_id" => "network--switch-to-nm" } }

      it "does not launchs the inst_lan client" do
        expect(Yast::WFM).to_not receive(:CallFuntion).with("inst_lan", anything)
      end

      it "changes the netwotk backend to NetworkManager" do
        expect(settings).to receive(:enable_network_manager!)

        subject.ask_user(args)
      end

      it "returns :next as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to include("workflow_sequence" => :next)
      end
    end
  end
end
