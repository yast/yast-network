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
require "y2network/interfaces/fake_interface"
require "y2network/connection_config/wireless"

describe Y2Network::Interfaces::FakeInterface do
  subject(:interface) { described_class.new("eth0", type: iface_type) }

  let(:iface_type) { Y2Network::InterfaceType::ETHERNET }

  describe ".from_connection" do
    let(:conn) do
      Y2Network::ConnectionConfig::Wireless.new.tap do |conn|
        conn.interface = "wlan0"
      end
    end

    it "returns a fake interface using the connection's type" do
      iface = described_class.from_connection("wlan0", conn)
      expect(iface.type).to eq(Y2Network::InterfaceType::WIRELESS)
    end
  end
end
