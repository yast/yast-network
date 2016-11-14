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
    let(:ipaddr) { "192.168.0.120" }
    let(:managed) { { "STARTMODE" => "managed" } }
    let(:static) { { "BOOTPROTO" => "static", "IPADDR" => ipaddr } }
    let(:empty) { { "BOOTPROTO" => "", "IPADDR" => ipaddr } }
    let(:no_bootproto) { { "IPADDR" => ipaddr } }
    # IPADDR are set just to show that returns the protocol instead of the IP
    let(:dhcp) { { "BOOTPROTO" => "dhcp", "IPADDR" => ipaddr } }
    let(:none) { { "BOOTPROTO" => "none", "IPADDR" => ipaddr } }

    it "returns _('Managed') if the interface is managed by NetworkManager" do
      expect(subject.DeviceProtocol(managed)).to eql(_("Managed"))
    end

    it "returns the IP address in case that BOOTPROTO is empty" do
      expect(subject.DeviceProtocol(empty)).to eql(ipaddr)
    end

    it "returns the IP address in case of no BOOTPROTO" do
      expect(subject.DeviceProtocol(no_bootproto)).to eql(ipaddr)
    end

    it "returns 'NONE' in case of static config and IPADDR == '0.0.0.0'" do
      expect(subject.DeviceProtocol(static.merge("IPADDR" => "0.0.0.0"))).to eql("NONE")
    end

    it "returns the IP address in case of static config" do
      expect(subject.DeviceProtocol(static)).to eql(ipaddr)
    end

    it "returns BOOTPROTO converted to uppercase" do
      expect(subject.DeviceProtocol(none)).to eql("NONE")
      expect(subject.DeviceProtocol(dhcp)).to eql("DHCP")
    end
  end

  describe "#use_udev_rule_for_bonding!" do
    before do
      Yast::LanItems.current = 0
      Yast::LanItems.Items = {
        0 => {
          "hwinfo" => {
            "dev_name" => "test0",
            "busid"    => "00:08:00"
          },
          "udev"   => {
            "net" => ["ATTR{address}==\"01:02:03:04:05\"", "KERNEL==\"eth*\"", "NAME=\"test0\""]
          }
        }
      }
      allow(Yast::LanItems).to receive(:dev_port).and_return("0")
    end

    it "uses KERNELS attribute with busid match instead of mac address" do
      allow(Yast::LanItems).to receive(:dev_port?).and_return(false)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["ATTR{address}==\"01:02:03:04:05\"", "KERNEL==\"eth*\"", "NAME=\"test0\""])
      subject.use_udev_rule_for_bonding!
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""])
    end

    it "adds the dev_port to the current rule if present in sysfs" do
      allow(Yast::LanItems).to receive(:dev_port?).and_return(true)
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["ATTR{address}==\"01:02:03:04:05\"", "KERNEL==\"eth*\"", "NAME=\"test0\""])
      subject.use_udev_rule_for_bonding!
      expect(Yast::LanItems.Items[0]["udev"]["net"])
        .to eql(["KERNEL==\"eth*\"", "ATTR{dev_port}==\"0\"", "KERNELS==\"00:08:00\"", "NAME=\"test0\""])
    end
  end
end
