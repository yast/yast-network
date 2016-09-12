#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/network_autoconfiguration"
require_relative "../src/clients/inst_setup_dhcp"

describe Yast::SetupDhcp do
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
