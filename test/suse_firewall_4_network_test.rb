#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

module Yast
  import "SuSEFirewall4Network"
  import "ServicesProposal"
  import "Pkg"

  describe SuSEFirewall4Network do
    before(:each) do
      # By default, activate firewall and block ssh
      allow(ProductFeatures).to receive(:GetBooleanFeature) do |*args|
        case args[1]
        when "enable_firewall"
          true
        when "firewall_enable_ssh"
          false
        when "enable_sshd"
          true
        end
      end
    end

    describe "#SetSshdEnabled" do
      it "sets whether sshd service should be started and caches the information in ServicesProposal" do
        SuSEFirewall4Network.SetSshdEnabled(true)
        expect(SuSEFirewall4Network.EnabledSshd).to be true
        expect(ServicesProposal.enabled_services.include?("sshd")).to be true
        expect(ServicesProposal.disabled_services.include?("sshd")).to be false

        SuSEFirewall4Network.SetSshdEnabled(false)
        expect(SuSEFirewall4Network.EnabledSshd).to be false
        expect(ServicesProposal.enabled_services.include?("sshd")).to be false
        expect(ServicesProposal.disabled_services.include?("sshd")).to be true
      end
    end

    describe "#prepare_proposal" do
      context "when firewall package is selected for installation" do
        before(:each) do
          allow(Pkg).to receive(:IsSelected).and_return true
        end

        it "proposes firewall and ssh port according to control file" do
          SuSEFirewall4Network.prepare_proposal
          expect(SuSEFirewall4Network.Enabled1stStage).to be true
          expect(SuSEFirewall4Network.EnabledSsh1stStage).to be false
        end
      end

      context "when firewall package is not selected for installation" do
        before(:each) do
          allow(Pkg).to receive(:IsSelected).and_return false
        end

        it "proposes disabled firewall and proposes ssh port according to control file" do
          SuSEFirewall4Network.prepare_proposal
          expect(SuSEFirewall4Network.Enabled1stStage).to be false
          expect(SuSEFirewall4Network.EnabledSsh1stStage).to be false
        end
      end
    end

    describe "ProtectByFirewall" do
      Yast.import "SuSEFirewall"

      context "when interface is not in fw zone" do
        before(:each) do
          allow(SuSEFirewall)
            .to receive(:SetEnableService)
          allow(SuSEFirewall)
            .to receive(:SetStartService)
        end

        it "doesn't cause modification flag to be set when protect status is true" do
          allow(SuSEFirewall)
            .to receive(:GetInterfacesInZone)
            .and_return(["eth0"])

          SuSEFirewall4Network.ProtectByFirewall("eth0", "INT", true)

          # interface is in the zone already => no adding / modification needed
          expect(SuSEFirewall.GetModified).to be false
        end

        it "doesn't cause modification flag to be set when protect status is false" do
          allow(SuSEFirewall)
            .to receive(:GetInterfacesInZone)
            .and_return([])

          # Note: zone is not important in this case
          SuSEFirewall4Network.ProtectByFirewall("eth0", "INT", false)

          # every zone is empty => no removal / modification needed
          expect(SuSEFirewall.GetModified).to be false
        end
      end
    end
  end
end
