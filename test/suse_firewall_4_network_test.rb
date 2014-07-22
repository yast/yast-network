#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

module Yast
  import "SuSEFirewall4Network"
  import "ServicesProposal"

  describe SuSEFirewall4Network do
    describe "#SetSshdEnabled" do
      it "sets whether sshd service should be started and caches the information in ServicesProposal" do
        SuSEFirewall4Network.SetSshdEnabled(true)
        expect(SuSEFirewall4Network.EnabledSshd).to be_true
        expect(ServicesProposal.enabled_services.include?('sshd')).to be_true
        expect(ServicesProposal.disabled_services.include?('sshd')).to be_false

        SuSEFirewall4Network.SetSshdEnabled(false)
        expect(SuSEFirewall4Network.EnabledSshd).to be_false
        expect(ServicesProposal.enabled_services.include?('sshd')).to be_false
        expect(ServicesProposal.disabled_services.include?('sshd')).to be_true
      end
    end
  end
end
