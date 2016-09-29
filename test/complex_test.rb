#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
include Yast::I18n

Yast.import "LanItems"
Yast.import "Stage"

class NetworkLanComplexIncludeClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/complex.rb"
  end
end

describe "NetworkLanComplexInclude" do
  subject { NetworkLanComplexIncludeClass.new }

  describe "#input_done?" do
    BOOLEAN_PLACEHOLDER = "placeholder (true or false)".freeze

    context "when not running in installer" do
      before(:each) do
        allow(Yast::Stage)
          .to receive(:initial)
          .and_return(false)
      end

      it "returns true for input different than :abort" do
        expect(subject.input_done?(:no_abort)).to eql true
      end

      it "returns true for input equal to :abort in case of no user modifications" do
        allow(Yast::LanItems)
          .to receive(:GetModified)
          .and_return(false)

        expect(subject.input_done?(:abort)).to eql true
      end

      it "asks user for abort confirmation for input equal to :abort and user did modifications" do
        allow(Yast::LanItems)
          .to receive(:GetModified)
          .and_return(true)

        expect(subject)
          .to receive(:ReallyAbort)
          .and_return(BOOLEAN_PLACEHOLDER)

        expect(subject.input_done?(:abort)).to eql BOOLEAN_PLACEHOLDER
      end
    end

    context "when running in installer" do
      before(:each) do
        allow(Yast::Stage)
          .to receive(:initial)
          .and_return(true)
      end

      it "asks user for installation abort confirmation for input equal to :abort" do
        expect(Yast::Popup)
          .to receive(:ConfirmAbort)
          .and_return(BOOLEAN_PLACEHOLDER)

        expect(subject.input_done?(:abort)).to eql BOOLEAN_PLACEHOLDER
      end
    end
  end

  describe "#DeviceProtocol" do
    let(:managed) { { "STARTMODE" => "managed" } }
    let(:static) { { "BOOTPROTO" => "static", "IPADDR" => "192.168.0.120" } }
    let(:empty) { { "BOOTPROTO" => "", "IPADDR" => "192.168.0.120" } }
    let(:no_bootproto) { { "IPADDR" => "192.168.0.120" } }
    # IPADDR are set just to show that returns the protocol instead of the IP
    let(:dhcp) { { "BOOTPROTO" => "dhcp", "IPADDR" => "192.168.0.120" } }
    let(:none) { { "BOOTPROTO" => "none", "IPADDR" => "192.168.0.120" } }

    it "returns _('Managed') if the interface is managed by NetworkManager" do
      expect(subject.DeviceProtocol(managed)).to eql(_("Managed"))
    end

    it "returns the IP address in case that BOOTPROTO is empty" do
      expect(subject.DeviceProtocol(empty)).to eql("192.168.0.120")
    end

    it "returns the IP address in case of no BOOTPROTO" do
      expect(subject.DeviceProtocol(no_bootproto)).to eql("192.168.0.120")
    end

    it "returns the IP address in case of static config" do
      expect(subject.DeviceProtocol(static)).to eql("192.168.0.120")
    end

    it "returns BOOTPROTO converted to uppercase" do
      expect(subject.DeviceProtocol(none)).to eql("NONE")
      expect(subject.DeviceProtocol(dhcp)).to eql("DHCP")
    end
  end
end
