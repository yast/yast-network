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
require "y2network/connection_config/ethernet"

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
        builder.boot_protocol = "static"
        builder.ip_address = "10.5.0.6"
        builder.subnet_prefix = "24"
        builder.hostname = "pepa"
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
        builder.boot_protocol = "dhcp"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "dhcp4 configuration" do
      before do
        builder.boot_protocol = "dhcp4"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "dhcp6 configuration" do
      before do
        builder.boot_protocol = "dhcp6"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "dhcp+autoip configuration" do
      before do
        builder.boot_protocol = "dhcp+autoip"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "autoip configuration" do
      before do
        builder.boot_protocol = "autoip"
        allow(subject).to receive(:value).and_return(:bootproto_dynamic)
      end

      it "does not crash" do
        subject.init
      end
    end

    context "none configuration" do
      before do
        builder.boot_protocol = "none"
      end

      it "does not crash" do
        subject.init
      end
    end

    context "ibft configuration" do
      before do
        builder.boot_protocol = "ibft"
      end

      it "does not crash" do
        subject.init
      end
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return(:"bootproto_#{value}")
    end

    context "none configuration selected" do
      let(:value) { "none" }

      it "sets bootproto to ibft if ibft is selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:bootproto_ibft), :Value).and_return(true)

        subject.store

        expect(builder.boot_protocol.name).to eq "ibft"
      end

      it "sets bootproto to none if ibft is not selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:bootproto_ibft), :Value).and_return(false)

        subject.store

        expect(builder.boot_protocol.name).to eq "none"
      end
    end

    context "static configuration selected" do
      let(:value) { "static" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).and_return("")
      end

      it "sets bootproto to static" do
        subject.store

        expect(builder.boot_protocol.name).to eq "static"
      end

      it "sets ipaddr to value of ip address widget" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_ipaddr, :Value)
          .and_return("10.100.0.1")

        subject.store

        expect(builder.ip_address).to eq "10.100.0.1"
      end

      it "sets hostname to value of hostname widget" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_hostname, :Value)
          .and_return("test.suse.cz")

        subject.store

        expect(builder.hostname).to eq "test.suse.cz"
      end

      it "sets prefixlen when value of netmast start with '/'" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_netmask, :Value).and_return("/24")

        subject.store

        expect(builder.subnet_prefix).to eq "/24"
      end

      it "sets prefixlen for ipv6" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_netmask, :Value).and_return("124")

        subject.store

        expect(builder.subnet_prefix).to eq "/124"
      end

      xit "sets netmask for ipv4 netmask value" do
        pending "drop netmask"
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_netmask, :Value)
          .and_return("255.255.0.0")

        subject.store

        expect(builder.subnet_prefix).to eq "255.255.0.0"
      end
    end

    context "dynamic configuration selected" do
      let(:value) { "dynamic" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dyn, :Value)
          .and_return(:bootproto_auto)
      end

      it "sets bootproto to dhcp when dhcp for ipv4 and ipv6 is selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dyn, :Value)
          .and_return(:bootproto_dhcp)
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dhcp_mode, :Value)
          .and_return(:bootproto_dhcp_both)

        subject.store

        expect(builder.boot_protocol.name).to eq "dhcp"
      end

      it "sets bootproto to dhcp4 when dhcp for ipv4 only is selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dyn, :Value)
          .and_return(:bootproto_dhcp)
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dhcp_mode, :Value)
          .and_return(:bootproto_dhcp_v4)

        subject.store

        expect(builder.boot_protocol.name).to eq "dhcp4"
      end

      it "sets bootproto to dhcp6 when dhcp for ipv6 only is selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dyn, :Value)
          .and_return(:bootproto_dhcp)
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dhcp_mode, :Value)
          .and_return(:bootproto_dhcp_v6)

        subject.store

        expect(builder.boot_protocol.name).to eq "dhcp6"
      end

      it "sets bootproto to dhcp+autoip when dhcp and zeroconf is selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dyn, :Value)
          .and_return(:bootproto_dhcp_auto)

        subject.store

        expect(builder.boot_protocol.name).to eq "dhcp+autoip"
      end

      it "sets bootproto to autoip when zeroconf is selected" do
        allow(Yast::UI).to receive(:QueryWidget).with(:bootproto_dyn, :Value)
          .and_return(:bootproto_auto)

        subject.store

        expect(builder.boot_protocol.name).to eq "autoip"
      end
    end
  end

  describe "#handle" do
    context "switched to static boot protocol" do
      let(:value) { "static" }

      before do
        allow(Yast::UI).to receive(:QueryWidget).with(Id(:bootproto_ipaddr), :Value)
          .and_return("")
      end

      it "does not propose hostname if current hostname is missing" do
        allow(Yast::DNS).to receive(:hostname).and_return(nil)

        expect(Yast::UI).to_not receive(:ChangeWidget)
          .with(Id(:bootproto_hostname), :Value, anything)
      end
    end
  end
end
