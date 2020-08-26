# Copyright (c) [2020] SUSE LLC
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
require "y2network/autoinst_profile/s390_device_section"
require "y2network/connection_config/ip_config"

describe Y2Network::AutoinstProfile::S390DevicesSection do
  subject(:section) { described_class.new }

  describe ".new_from_network" do
    let(:config) do
      Y2Network::ConnectionConfig::Qeth.new.tap do |c|
        c.bootproto = Y2Network::BootProtocol::STATIC
        c.interface = "eth0"
      end
    end

    let(:parent) { double("Installation::AutoinstProfile::SectionWithAttributes") }

    it "initializes s390 devices values properly" do
      section = described_class.new_from_network([config])
      expect(section.devices)
        .to contain_exactly(a_kind_of(Y2Network::AutoinstProfile::S390DeviceSection))
    end

    it "sets the parent section" do
      section = described_class.new_from_network([config], parent)
      expect(section.parent).to eq(parent)
    end
  end
end
