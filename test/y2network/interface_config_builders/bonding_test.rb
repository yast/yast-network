#!/usr/bin/env rspec

# Copyright (c) [2019-2020] SUSE LLC
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

require "yast"
require "y2network/interface_config_builders/bonding"

describe Y2Network::InterfaceConfigBuilders::Bonding do
  let(:config) { Y2Network::Config.new(source: :test) }
  let(:dhcp) { Y2Network::BootProtocol::DHCP }
  let(:none) { Y2Network::BootProtocol::NONE }
  let(:hotplug) { Y2Network::Startmode.create("hotplug") }
  let(:auto) { Y2Network::Startmode.create("auto") }

  before do
    allow(config).to receive(:interfaces).and_return(interfaces_collection)
    allow(config).to receive(:connections).and_return(connection_configs_collection)
    allow(connection_config).to receive(:name).and_return(connection_name)
    allow(connection_config).to receive(:find_parent).and_return(connection_parent)
    allow(Yast::Arch).to receive(:s390).and_return(s390)
  end

  let(:s390) { false }

  let(:interfaces_collection) do
    Y2Network::InterfacesCollection.new([interface1, interface2])
  end

  let(:connection_configs_collection) do
    Y2Network::ConnectionConfigsCollection.new([connection_config])
  end

  let(:interface1) { Y2Network::Interface.new("iface1") }
  let(:interface2) { Y2Network::Interface.new("iface2") }
  let(:connection_config) { Y2Network::ConnectionConfig::Bonding.new }
  let(:connection_name) { "" }
  let(:connection_parent) { nil }

  before do
    allow(Y2Network::Config)
      .to receive(:find)
      .with(:yast)
      .and_return(config)
  end

  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilders::Bonding.new(config: connection_config)
    res.name = "bond0"
    res
  end

  describe "#type" do
    it "returns bonding interface type" do
      expect(subject.type).to eq Y2Network::InterfaceType::BONDING
    end
  end

  describe "#bondable_interfaces" do
    shared_examples "interface filters" do
      context "and the interface does not have a connection config yet" do
        let(:connection_name) { "iface2" } # only iface2 has a config

        it "includes the interface without a connection config" do
          expect(subject.bondable_interfaces).to include(interface1)
        end
      end

      context "and the interface has a connection config" do
        let(:connection_name) { "iface1" }

        context "and there already is a parent connection" do
          let(:connection_parent) do
            instance_double(Y2Network::ConnectionConfig::Bonding, name: "bond1")
          end

          it "does not include the interface" do
            expect(subject.bondable_interfaces).to_not include(interface1)
          end
        end

        context "and there is no parent connection yet" do
          let(:connection_parent) { nil }

          it "includes the interface" do
            expect(subject.bondable_interfaces).to include(interface1)
          end
        end
      end
    end

    it "returns an array" do
      expect(subject.bondable_interfaces).to be_a(::Array)
    end

    context "when the architecture is s390" do
      let(:s390) { true }
      let(:interface1) { Y2Network::Interface.new("iface1", type: Y2Network::InterfaceType::QETH) }
      let(:interface2) { Y2Network::Interface.new("iface2", type: Y2Network::InterfaceType::QETH) }

      before do
        allow(Yast::FileUtils).to receive(:IsDirectory).and_return(true)
      end

      context "and the interface has no L2 support" do
        before do
          allow(Yast::SCR).to receive(:Read).with(anything, /.*iface1.*\/layer2/).and_return("0\n")
        end

        it "does not include the interface" do
          expect(subject.bondable_interfaces).to_not include(interface1)
        end
      end

      context "and the interface has L2 support" do
        before do
          allow(Yast::SCR).to receive(:Read).with(anything, /.*iface1.*\/layer2/).and_return("1\n")
        end

        include_examples "interface filters"
      end
    end

    context "when the architecture is not s390 or the interface is an ethernet one" do
      let(:s390) { false }

      include_examples "interface filters"
    end
  end

  describe "require_adaptation?" do
    before do
      connection_config.ports = ["iface1", "iface2"]
    end

    context "when there is no port configured" do
      it "returns false" do
        expect(subject.require_adaptation?(connection_config.ports)).to eql(false)
      end
    end

    context "when all the ports are properly configure do" do
      it "returns false" do
        subject.save
        expect(subject.require_adaptation?(connection_config.ports)).to eql(false)
      end
    end

    context "when at least one configured slave need to be adapted" do
      it "returns true" do
        subject.save
        iface1_conn = connection_configs_collection.by_name("iface1")
        iface1_conn.bootproto = dhcp
        expect(subject.require_adaptation?(connection_config.ports)).to eql(true)
      end
    end
  end

  describe "#save" do
    let(:connection_name) { "bond0" }

    it "adapts the selected ports configuration when needed" do
      connection_config.ports = ["iface1", "iface2"]

      expect(Y2Network::InterfaceConfigBuilder)
        .to receive(:for).with(anything, config: nil).twice.and_call_original
      subject.save
      iface1_conn = connection_configs_collection.by_name("iface1")
      iface2_conn = connection_configs_collection.by_name("iface2")
      iface2_conn.bootproto = dhcp
      expect(Y2Network::InterfaceConfigBuilder)
        .to receive(:for).with(anything, config: iface2_conn).once.and_call_original
      expect(Y2Network::InterfaceConfigBuilder)
        .to_not receive(:for).with(anything, config: iface1_conn)
      subject.save
    end

    it "sets the BOOTPROTO to 'none' and STARTMODE to 'hotplug' in the adapted configs" do
      connection_config.ports = ["iface1", "iface2"]
      subject.save
      iface2_conn = connection_configs_collection.by_name("iface2")
      iface2_conn.bootproto = dhcp
      expect { subject.save }.to change { iface2_conn.bootproto }.from(dhcp).to(none)
      iface2_conn.startmode = auto
      expect { subject.save }.to change { iface2_conn.startmode }.from(auto).to(hotplug)
    end
  end
end
