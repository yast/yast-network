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

require_relative "../../test_helper"
require "cwm/rspec"

require "y2network/widgets/boot_protocol"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::BootProtocol do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("eth") }
  subject { described_class.new(builder) }

  before do
    allow(subject).to receive(:value).and_return(:bootproto_none)
    allow(Yast::UI).to receive(:ChangeWidget)
  end

  include_examples "CWM::CustomWidget"

  def expect_set_widget(id, value, value_type: :Value)
    expect(Yast::UI).to receive(:ChangeWidget).with(Id(id), value_type, value)
  end

  describe "#init" do
    context "for other types then eth" do
      let(:builder) { Y2Network::InterfaceConfigBuilder.for("br") }

      it "hides iBFT checkbox" do
        expect(Yast::UI).to receive(:ReplaceWidget).with(:bootproto_rp, Empty())

        subject.init
      end
    end

    context "static configuration" do
      before do
        builder["BOOTPROTO"] = "static"
        builder["IPADDR"] = "10.5.0.6"
        builder["PREFIXLEN"] = "24"
        builder["HOSTNAME"] = "pepa"
        allow(subject).to receive(:value).and_return(:bootproto_static)
        allow(Yast::UI).to receive(:QueryWidget).and_return("pepa")
      end

      it "sets static configuration" do
        expect_set_widget(:bootproto, :bootproto_static, value_type: :CurrentButton)

        subject.init
      end

      it "sets ip address" do
        expect_set_widget(:bootproto_ipaddr, "10.5.0.6")

        subject.init
      end

      it "sets netmask" do
        expect_set_widget(:bootproto_netmask, "/24")

        subject.init
      end

      it "sets hostname" do
        expect_set_widget(:bootproto_hostname, "pepa")

        subject.init
      end
    end

    context "dhcp configuration" do
      before do
        builder["BOOTPROTO"] = "dhcp"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "dhcp4 configuration" do
      before do
        builder["BOOTPROTO"] = "dhcp4"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "dhcp6 configuration" do
      before do
        builder["BOOTPROTO"] = "dhcp6"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "dhcp+autoip configuration" do
      before do
        builder["BOOTPROTO"] = "dhcp+autoip"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "autoip configuration" do
      before do
        builder["BOOTPROTO"] = "autoip"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "none configuration" do
      before do
        builder["BOOTPROTO"] = "none"
      end

      it "does not crash" do
        subject.init
      end
    end

    context "ibft configuration" do
      before do
        builder["BOOTPROTO"] = "ibft"
      end

      it "does not crash" do
        subject.init
      end
    end
  end
end
