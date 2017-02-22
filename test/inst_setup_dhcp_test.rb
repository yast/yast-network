#!/usr/bin/env rspec

require_relative "test_helper"

require "network/clients/inst_setup_dhcp"

describe Yast::SetupDhcp do
  before do
    allow(Yast::NetworkInterfaces).to receive(:adapt_old_config!)
  end

  describe "#main" do

    it "returns :next when autoconfiguration is performed" do
      allow(Yast::NetworkAutoconfiguration)
        .to receive(:any_iface_active?)
        .and_return(true)

      expect(Yast::SetupDhcp.instance.main).to eql :next
    end

    it "returns :next when autoconfiguration is not performed" do
      allow(Yast::NetworkAutoconfiguration)
        .to receive(:any_iface_active?)
        .and_return(false)

      expect(Yast::SetupDhcp.instance.main).to eql :next
    end
  end
end
