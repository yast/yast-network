#!/usr/bin/env rspec

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

require_relative "test_helper"

require "network/clients/network_proposal"
require "y2network/presenters/proposal_summary"

describe Yast::NetworkProposal do
  Yast.import "Lan"

  let(:proposal_summary) do
    double(
      "Y2Network::Presenters::ProposalSummary",
      one_line_text: "one_line_summary", text: "rich_text_summary"
    )
  end

  before do
    stub_const("Yast::Wizard", double.as_null_object)
    allow(subject).to receive(:proposal_summary).and_return(proposal_summary)
  end

  describe "#description" do
    it "returns a map with id, menu_title and rich_text_title " do
      expect(subject.description).to include("id", "menu_title", "rich_text_title")
    end
  end

  describe "#make_proposal" do
    let(:settings) { Y2Network::ProposalSettings.create_instance }
    let(:current_backend) { :wicked }
    let(:nm_available) { true }
    let(:proposal) { subject.make_proposal({}) }
    let(:virt_installed) { false }

    before do
      settings.selected_backend = current_backend
      allow(settings).to receive(:network_manager_available?).and_return(nm_available)
      allow(settings).to receive(:virtual_proposal_required?).and_return(virt_installed)
    end

    it "returns a hash describing the proposal" do
      expect(proposal).to include("label_proposal", "preformatted_proposal", "links")
    end

    context "when NetworkManager is not available" do
      let(:nm_available) { false }

      it "includes the Yast::Lan proposal summary" do
        expect(proposal["preformatted_proposal"]).to include("rich_text_summary")
      end

      it "does not include any link to switch between backends" do
        expect(proposal["preformatted_proposal"]).to_not match(/.*Using*.*href.*.switch to*./)
      end
    end

    context "when using the wicked backend" do
      it "includes the Yast::Lan proposal summary" do
        expect(proposal["preformatted_proposal"]).to include("rich_text_summary")
      end

      it "includes a link to switch to NetworkManager" do
        expect(proposal["preformatted_proposal"]).to match(/.*href.*NetworkManager.*/)
      end

      it "does not include a link to switch to wicked" do
        expect(proposal["preformatted_proposal"]).to_not match(/.*href.*wicked.*/)
      end
    end

    context "when using the NetworkManager backend" do
      let(:current_backend) { :network_manager }

      it "includes the Yast::Lan proposal summary" do
        expect(proposal["preformatted_proposal"]).to include("rich_text_summary")
      end

      it "does not include a link to switch to NetworkManager" do
        expect(proposal["preformatted_proposal"]).to_not match(/.*href.*NetworkManager.*/)
      end

      it "includes a link to switch to wicked" do
        expect(proposal["preformatted_proposal"]).to match(/.*href.*wicked.*/)
      end
    end

    context "when selected to disable network services" do
      let(:current_backend) { :none }

      it "does not include the Yast::Lan proposal summary" do
        expect(proposal["preformatted_proposal"]).to_not include("rich_text_summary")
      end

      it "shows that network services will be disabled" do
        expect(proposal["preformatted_proposal"]).to match(/Network Services Disabled/)
      end

      it "includes a link to switch to wicked" do
        expect(proposal["preformatted_proposal"]).to match(/.*href.*wicked.*/)
      end

      it "includes a link to switch to NetworkManager" do
        expect(proposal["preformatted_proposal"]).to match(/.*href.*NetworkManager.*/)
      end
    end

    context "when Xen, KVM or QEMU will be installed" do
      let(:virt_installed) { true }

      context "and the bridge proposal is enabled" do
        it "includes a link to disable the virt bridge network config proposal" do
          expect(proposal["preformatted_proposal"]).to match(/.*href.*Use non-bridge.*/)
        end
      end

      context "and the bridge proposal is disabled" do
        it "includes a link to enable the virt bridge network config proposal" do
          settings.propose_bridge!(false)
          expect(proposal["preformatted_proposal"]).to match(/.*href.*Use bridge.*/)
        end
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
        expect(Yast::WFM).to_not receive(:CallFunction).with("inst_lan", anything)
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
        expect(Yast::WFM).to_not receive(:CallFunction).with("inst_lan", anything)
      end

      it "changes the netwotk backend to NetworkManager" do
        expect(settings).to receive(:enable_network_manager!)

        subject.ask_user(args)
      end

      it "returns :next as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to include("workflow_sequence" => :next)
      end
    end

    context "when 'chosen_id' is 'network--disable'" do
      let(:args) { { "chosen_id" => "network--disable" } }

      it "sets the network backend to none" do
        expect(settings).to receive(:disable_network!)

        subject.ask_user(args)
      end

      it "returns :next as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to include("workflow_sequence" => :next)
      end
    end

    context "when 'chosen_id' is 'network--propose-bridge'" do
      let(:args) { { "chosen_id" => "network--propose-bridge" } }

      it "sets the bridge config for virtualization to be proposed" do
        expect(settings).to receive(:propose_bridge!).with(true)

        subject.ask_user(args)
      end

      it "returns :next as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to include("workflow_sequence" => :next)
      end
    end

    context "when 'chosen_id' is 'network--dont-propose-bridge'" do
      let(:args) { { "chosen_id" => "network--dont-propose-bridge" } }

      it "sets the bridge config for virtualization to not be proposed" do
        expect(settings).to receive(:propose_bridge!).with(false)

        subject.ask_user(args)
      end

      it "returns :next as 'workflow_sequence'" do
        expect(subject.ask_user(args)).to include("workflow_sequence" => :next)
      end
    end
  end
end
