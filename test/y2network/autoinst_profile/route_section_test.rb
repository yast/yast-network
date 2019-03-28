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
require "y2network/autoinst_profile/route_section"

describe Y2Network::AutoinstProfile::RouteSection do
  subject(:section) { described_class.new }

  describe ".new_from_hashes" do
    let(:hash) do
      {
        "destination" => "192.168.122.0",
        "netmask"     => "255.255.255.0",
        "device"      => "eth0",
        "gateway"     => "192.168.122.1",
        "extrapara"   => "foo"
      }
    end

    it "initializes destination" do
      section = described_class.new_from_hashes(hash)
      expect(section.destination).to eq(hash["destination"])
    end

    it "initializes netmask" do
      section = described_class.new_from_hashes(hash)
      expect(section.netmask).to eq(hash["netmask"])
      end

    it "initializes device" do
      section = described_class.new_from_hashes(hash)
      expect(section.device).to eq(hash["device"])
    end

    it "initializes gateway" do
      section = described_class.new_from_hashes(hash)
      expect(section.gateway).to eq(hash["gateway"])
    end

    it "initializes extrapara" do
      section = described_class.new_from_hashes(hash)
      expect(section.extrapara).to eq(hash["extrapara"])
    end
  end
end
