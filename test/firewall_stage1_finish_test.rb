#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require_relative "../src/clients/firewall_stage1_finish"

describe Yast::FirewallStage1FinishClient do
  describe "main" do
    context "when the client is called with 'Info'" do
      it "returns a hash with 'steps', 'title' and 'when' keys" do

        res = Yast::WFM.CallFunction("firewall_stage1_finish", ["Info"])

        expect(res).to be_a(Hash)
        expect(res).to include("steps", "title", "when")
      end
    end

    context "when the client is called with 'Write'" do
      before do
        allow(Yast::WFM).to receive(:Args).and_return("Write")
      end

      context "in autoninst Mode" do
        let(:installed) { false }

        before do
          allow(Yast::Mode).to receive(:autoinst).and_return(true)
          allow(Yast::SuSEFirewall).to receive(:WriteConfiguration)
          allow(Yast::Service).to receive(:Enable)
          allow(Yast::SuSEFirewall4Network).to receive(:IsInstalled).and_return(installed)
          allow(subject).to receive(:adjust_ay_configuration)
        end

        context "with SuSEfirewall2 installed" do
          let(:installed) { true }

          it "allows the remote installations in use in the SuSEFirewall configuration" do
            expect(subject).to receive(:adjust_ay_configuration)

            subject.main
          end
        end

        context "without SuSEFirewall installed" do
          it "does nothing special for AutoYaST" do
            expect(subject).to_not receive(:adjust_ay_configuration)

            subject.main
          end
        end
      end

      it "enables the sshd service in case of ssh remote installation" do
        expect(Yast::SuSEFirewall4Network).to receive(:EnabledSshd).and_return(true)
        expect(Yast::Service).to receive(:Enable).with("sshd")

        subject.main
      end

      it "writes the SuSEFirewall configuration" do
        expect(Yast::SuSEFirewall).to receive(:WriteConfiguration)

        subject.main
      end
    end
  end

  describe "#adjust_ay_configuration" do
    before do
      allow(Yast::Progress).to receive(:set)
      allow(Yast::SuSEFirewall).to receive(:Read)
      allow(subject).to receive(:open_ssh_port)
      allow(subject).to receive(:open_vnc_port)
      allow(Yast::Linuxrc).to receive(:useiscsi).and_return(false)
      allow(Yast::SuSEFirewall4Network).to receive(:Enabled1stStage).and_return(true)
    end

    context "when the user has not modified the proposal" do
      it "obtains the linuxrc options and defauls from the control file" do
        allow(Yast::SuSEFirewallProposal).to receive(:GetChangedByUser).and_return(false)
        expect(Yast::SuSEFirewall4Network).to receive(:prepare_proposal)

        subject.send(:adjust_ay_configuration)
      end
    end

    context "when the user has modified the proposal" do
      it "does not modify it" do
        allow(Yast::SuSEFirewallProposal).to receive(:GetChangedByUser).and_return(true)
        expect(Yast::SuSEFirewall4Network).to_not receive(:prepare_proposal)

        subject.send(:adjust_ay_configuration)
      end
    end

    it "returns if the firewall is not enabled" do
      expect(Yast::SuSEFirewall4Network).to receive(:Enabled1stStage).and_return(false)
      expect(Yast::SuSEFirewall4Network).to_not receive(:EnabledSsh1stStage)

      subject.send(:adjust_ay_configuration)
    end

    it "reads the firewall configuration" do
      expect(Yast::SuSEFirewall).to receive(:Read)

      subject.send(:adjust_ay_configuration)
    end

    it "opens remote access in the firewall when correspond" do
      expect(Yast::SuSEFirewall4Network).to receive(:EnabledSsh1stStage).and_return(true)
      expect(Yast::SuSEFirewall4Network).to receive(:EnabledVnc1stStage).and_return(false)
      expect(subject).to receive(:open_ssh_port).with(true)
      expect(subject).to receive(:open_vnc_port).with(false)

      subject.send(:adjust_ay_configuration)
    end

    it "enables firewall complete access in case of a iscsi installation" do
      expect(Yast::Linuxrc).to receive(:useiscsi).and_return(true)
      expect(Yast::SuSEFirewallProposal).to receive(:propose_iscsi)

      subject.send(:adjust_ay_configuration)
    end
  end
end
