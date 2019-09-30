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

require_relative "../../test_helper"
require "y2network/autoinst_profile/udev_rules_section"
require "y2network/autoinst/udev_rules_reader"
require "y2network/interface"

describe Y2Network::Autoinst::UdevRulesReader do
  let(:subject) { described_class.new(udev_rules_section) }
  let(:udev_rules_section) do
    Y2Network::AutoinstProfile::UdevRulesSection.new_from_hashes(udev_rules_profile)
  end

  let(:udev_rules_profile) do
    [
      {
        "name"  => "eth1",
        "rule"  => "KERNELS",
        "value" => "bus1"
      }
    ]
  end

  describe "#apply" do
    let(:config) do
      double(interfaces: Y2Network::InterfacesCollection.new([double(name: "eth0", hardware: double(busid: "bus1"))]), rename_interface: nil)
    end

    it "renames interface with matching hardware properties" do
      expect(config).to receive(:rename_interface).with("eth0", "eth1", :bus_id)
      subject.apply(config)
    end

    context "when there is already interface with matching name and non-matching hardware" do
      let(:config) do
        double(
          interfaces:       Y2Network::InterfacesCollection.new(
            [
              double(name: "eth0", hardware: double(busid: "bus1")),
              double(name: "eth1", hardware: double(busid: "bus2"))
            ]
          ),
          rename_interface: nil
        )
      end

      it "renames colliding interface to new free name" do
        expect(config).to receive(:rename_interface).with("eth1", "eth2", :mac)
        subject.apply(config)
      end
    end

    context "when there is no interface with matching hardware" do
      let(:config) do
        double(interfaces: Y2Network::InterfacesCollection.new([double(name: "eth0", hardware: double(busid: "bus2"))]), rename_interface: nil)
      end

      it "do nothing" do
        expect(config).to_not receive(:rename_interface)
      end
    end
  end
end
