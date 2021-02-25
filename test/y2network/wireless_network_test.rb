# Copyright (c) [2021] SUSE LLC
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
require "y2network/wireless_network"
require "y2network/wireless_auth_mode"

describe Y2Network::WirelessNetwork do
  subject(:network) do
    described_class.new(
      essid: "MY_WIFI", mode: "Master", channel: "Channel", rates: ["54 Mb/s"],
      quality: 70, auth_mode: Y2Network::WirelessAuthMode::NONE
    )
  end

  describe ".all" do
    let(:wireless_scanner) do
      instance_double(
        Y2Network::WirelessScanner, cells: [my_wifi_cell0, my_wifi_cell1, another_wifi_cell]
      )
    end

    let(:my_wifi_cell0) do
      Y2Network::WirelessCell.new(
        address: "00:11:22:33:44:55:01", essid: "MY_WIFI", mode: "Master", channel: 10,
        rates: ["54 Mb/s"], quality: 30, auth_mode: Y2Network::WirelessAuthMode::NONE
      )
    end

    let(:my_wifi_cell1) do
      Y2Network::WirelessCell.new(
        address: "00:11:22:33:44:02", essid: "MY_WIFI", mode: "Master", channel: 10,
        rates: ["54 Mb/s"], quality: 65, auth_mode: Y2Network::WirelessAuthMode::NONE
      )
    end

    let(:another_wifi_cell) do
      Y2Network::WirelessCell.new(
        address: "00:11:22:33:44:03", essid: "ANOTHER_WIFI", mode: "Master", channel: 3,
        rates: ["54 Mb/s"], quality: 42, auth_mode: Y2Network::WirelessAuthMode::NONE
      )
    end

    before do
      allow(Y2Network::WirelessScanner).to receive(:new)
        .with("wlo1").and_return(wireless_scanner)
    end

    it "returns one network for each ESSID" do
      expect(described_class.all("wlo1", cache: false)).to contain_exactly(
        an_object_having_attributes(
          essid: "MY_WIFI", mode: "Master", channel: 10, quality: 65
        ),
        an_object_having_attributes(
          essid: "ANOTHER_WIFI", mode: "Master", channel: 3, quality: 42
        )
      )
    end

    it "memoizes the the results" do
      described_class.all("wlo1")
      expect(Y2Network::WirelessScanner).to_not receive(:new)
      expect(described_class.all("wlo1", cache: true))
    end
  end
end
