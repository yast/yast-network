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
require "y2network/autoinst_profile/udev_rule_section"
require "y2network/connection_config/ip_config"

describe Y2Network::AutoinstProfile::UdevRuleSection do
  subject(:section) { described_class.new }

  describe ".new_from_network" do
    let(:hardware) do
      double(Y2Network::Hwinfo, mac: "mac1", busid: "bus1")
    end
    let(:interface) do
      double(Y2Network::Interface, renaming_mechanism: :mac, hardware: hardware, name: "eth0")
    end

    let(:parent) { double("Installation::AutoinstProfile::SectionWithAttributes") }

    it "initializes values properly" do
      section = described_class.new_from_network(interface)
      expect(section.name).to eq "eth0"
      expect(section.value).to eq "mac1"
      expect(section.rule).to eq "ATTR{address}"
    end

    it "sets the parent section" do
      section = described_class.new_from_network(interface, parent)
      expect(section.parent).to eq(parent)
    end
  end
end
