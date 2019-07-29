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
require "y2network/connection_configs_collection"
require "y2network/connection_config/ethernet"
require "y2network/connection_config/wireless"

describe Y2Network::ConnectionConfigsCollection do
  subject(:collection) { described_class.new(connections) }

  let(:connections) { [eth0, wlan0] }
  let(:eth0) { Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = "eth0" } }
  let(:wlan0) { Y2Network::ConnectionConfig::Wireless.new.tap { |c| c.name = "wlan0" } }

  describe "#by_name" do
    it "returns the connection configuration with the given name" do
      expect(collection.by_name("eth0")).to eq(eth0)
    end

    context "when name is not defined" do
      it "returns nil" do
        expect(collection.by_name("eth1")).to be_nil
      end
    end
  end

  describe "#update" do
    let(:eth0_1) { Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = "eth0" } }

    it "replaces the connection configuration having the same name with the given object" do
      collection.update(eth0_1)
      expect(collection.by_name("eth0")).to be(eth0_1)
    end
  end
end
