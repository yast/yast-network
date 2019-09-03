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
        expect(described_class.for("ib").class.to_s).to eq "Y2Network::InterfaceConfigBuilders::Infiniband"
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
    around do |block|
      Yast::LanItems.AddNew
      # FIXME: workaround for device without reading hwinfo, so udev is not initialized
      Yast::LanItems.Items[Yast::LanItems.current]["udev"] = {}
      block.call
      Yast::LanItems.Rollback
    end

    it "stores driver configuration" do
      subject.driver = "e1000e"
      subject.driver_options = "test"
      subject.save
      expect(Yast::LanItems.Items[Yast::LanItems.current]["udev"]["driver"]).to eq "e1000e"
      expect(Yast::LanItems.driver_options["e1000e"]).to eq "test"
    end

    it "saves connection config" do
      expect(config).to receive(:add_or_update_connection_config).with(Y2Network::ConnectionConfig::Base)
      subject.save
    end

    context "when interface was renamed" do
      before do
        subject.rename_interface("eth2")
        subject.renaming_mechanism = :mac
      end

      it "updates the name in the configuration" do
        expect(Yast::Lan.yast_config).to receive(:rename_interface)
          .with("eth0", "eth2", :mac)
        subject.save
      end
    end

    context "when interface was not renamed" do
      it "does not alter the name" do
        expect(Yast::Lan.yast_config).to_not receive(:rename_interface)
        subject.save
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
end
