#!/usr/bin/env rspec

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

require_relative "../test_helper"

require "yast"
require "y2network/interface_config_builder"
require "y2network/interfaces_collection"
require "y2network/physical_interface"

Yast.import "Lan"

describe Y2Network::InterfaceConfigBuilder do
  subject(:config_builder) do
    res = Y2Network::InterfaceConfigBuilder.for("eth")
    res.name = "eth0"
    res
  end

  let(:config) { Y2Network::Config.new(interfaces: interfaces, source: :sysconfig) }
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0]) }
  let(:eth0) { Y2Network::PhysicalInterface.new("eth0") }

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(config)
  end

  describe ".for" do
    context "specialized class for given type exists" do
      it "returns new instance of that class" do
        expect(described_class.for("ib").class.to_s).to eq(
          "Y2Network::InterfaceConfigBuilders::Infiniband"
        )
      end
    end

    context "specialized class for given type does NOT exist" do
      it "returns instance of InterfaceConfigBuilder" do
        expect(described_class.for("eth").class).to eq described_class
      end

      it "sets type to passed type as InterfaceType" do
        expect(described_class.for("dummy").type).to eq Y2Network::InterfaceType::DUMMY
      end
    end
  end

  describe "#save" do
    let(:driver) { Y2Network::Driver.new("virtio_net", "csum=1") }

    it "stores driver configuration" do
      expect(config).to receive(:add_or_update_driver).with(driver)
      subject.driver = driver
      subject.save
    end

    context "when a driver is selected" do
      before do
        config_builder.driver = driver
      end

      it "sets the interface driver" do
        expect(eth0).to receive(:custom_driver=).with(driver.name)
        subject.save
      end

      it "updates the driver" do
        expect(config).to receive(:add_or_update_driver).with(driver)
        subject.save
      end
    end

    context "when no driver is selected" do
      before do
        config_builder.driver = :auto
      end

      it "sets the interface driver to nil" do
        expect(eth0).to receive(:custom_driver=).with(nil)
        subject.save
      end

      it "does not update any driver" do
        expect(config).to_not receive(:add_or_update_driver)
        subject.save
      end
    end

    it "saves connection config" do
      expect(config).to receive(:add_or_update_connection_config)
        .with(Y2Network::ConnectionConfig::Base)
      subject.save
    end

    context "when the new connection config is for an unplugged interface" do
      subject(:config_builder) do
        res = Y2Network::InterfaceConfigBuilder.for("eth")
        res.name = "eth1"
        res
      end

      it "assigns the added interface to the builder" do
        subject.save
        expect(subject.interface.name).to eq("eth1")
      end
    end

    context "when interface was renamed" do
      before do
        subject.rename_interface("eth2")
        subject.renaming_mechanism = :mac
      end

      it "updates the name in the configuration" do
        expect(config).to receive(:rename_interface)
          .with("eth0", "eth2", :mac)
        subject.save
      end
    end

    context "when interface was not renamed" do
      it "does not alter the name" do
        expect(config).to_not receive(:rename_interface)
        subject.save
      end
    end

    context "when aliases are defined" do
      before do
        subject.aliases = [
          { id: "_1", ip_address: "192.168.122.100", subnet_prefix: "/24", label: "alias1" },
          { id: "suffix1", ip_address: "192.168.123.100", subnet_prefix: "/24", label: "alias2" },
          { ip_address: "10.0.0.2", label: "alias3" },
          { id: "", ip_address: "10.0.0.3", label: "alias4" }
        ]
      end

      it "sets aliases for the connection config" do
        subject.save
        expect(subject.connection_config.ip_aliases).to eq(
          [
            Y2Network::ConnectionConfig::IPConfig.new(
              Y2Network::IPAddress.from_string("192.168.122.100/24"), id: "_1", label: "alias1"
            ),
            Y2Network::ConnectionConfig::IPConfig.new(
              Y2Network::IPAddress.from_string("192.168.123.100/24"), id: "suffix1", label: "alias2"
            ),
            Y2Network::ConnectionConfig::IPConfig.new(
              Y2Network::IPAddress.from_string("10.0.0.2"), id: "_2", label: "alias3"
            ),
            Y2Network::ConnectionConfig::IPConfig.new(
              Y2Network::IPAddress.from_string("10.0.0.3"), id: "_3", label: "alias4"
            )
          ]
        )
      end
    end
  end

  describe "#rename_interface" do
    it "updates the interface name" do
      expect { config_builder.rename_interface("eth2") }
        .to change { config_builder.name }.from("eth0").to("eth2")
    end
  end

  describe "#renamed_interface?" do
    context "when the interface name has not been changed" do
      it "returns false" do
        expect(config_builder.renamed_interface?).to eq(false)
      end

      context "but it was initially renamed by udev" do
        before do
          allow(eth0).to receive(:renaming_mechanism).and_return(:mac)
        end

        it "returns false" do
          expect(config_builder.renamed_interface?).to eq(false)
        end
      end
    end

    context "when the interface has been renamed" do
      before do
        config_builder.rename_interface("eth2")
      end

      it "returns true" do
        expect(config_builder.renamed_interface?).to eq(true)
      end
    end

    context "when the renaming mechanism has been changed" do
      before do
        config_builder.renaming_mechanism = :busid
      end

      it "returns true" do
        expect(config_builder.renamed_interface?).to eq(true)
      end
    end

    context "when the old name and mechanism have been restored " do
      before do
        config_builder.rename_interface("eth2")
        config_builder.renaming_mechanism = :mac
      end

      it "returns false" do
        config_builder.rename_interface("eth0")
        config_builder.renaming_mechanism = :none
        expect(config_builder.renamed_interface?).to eq(false)
      end
    end
  end

  describe "#hwinfo_from" do
    let(:hwinfo) { { "dev_name" => "", "busid" => "0.0.0700" } }

    it "overrides the builder hwinfo with the given hardware info" do
      config_builder.hwinfo_from(hwinfo)
      expect(config_builder.hwinfo.busid).to eq("0.0.0700")
    end
  end

  describe "#hostname=" do
    it "sets the hostname for the connection config" do
      expect(subject.connection_config).to receive(:hostname=).with("foo").and_call_original
      expect { subject.hostname = "foo" }.to change { subject.hostname }
        .from("").to("foo")
    end
  end

  describe "#alias_for" do
    let(:ip_settings) do
      Y2Network::ConnectionConfig::IPConfig.new(
        Y2Network::IPAddress.from_string("192.168.122.100/24"), id: "_1", label: "alias1"
      )
    end

    it "obtains a new hash from the given additional IP address config" do
      expect(subject.alias_for(ip_settings)).to eq(
        id: "_1", ip_address: "192.168.122.100", subnet_prefix: "/24", label: "alias1"
      )
    end

    context "when no IP config is given" do
      it "generates a new hash with empty values" do
        expect(subject.alias_for(nil)).to eq(
          id: "", ip_address: "", subnet_prefix: "", label: ""
        )
      end
    end
  end
end
