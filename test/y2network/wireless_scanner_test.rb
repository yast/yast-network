#!/usr/bin/env rspec
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

require "y2network/wireless_scanner"
require "y2network/wireless_auth_mode"

describe Y2Network::WirelessScanner do
  subject(:scanner) { described_class.new("wlo1") }

  describe "#networks" do
    let(:iwlist) { File.read(File.join(DATA_PATH, "iwlist.txt")) }

    before do
      allow(Yast::Execute).to receive(:locally)
        .with(["/usr/sbin/ip", "link", "set", "wlo1", "up"])
      allow(Yast::Execute).to receive(:locally!)
        .with(["/usr/sbin/iwlist", "wlo1", "scan"], stdout: :capture)
        .and_return(iwlist)
    end

    it "returns the wireless networks" do
      expect(scanner.cells).to contain_exactly(
        an_object_having_attributes(
          address: "68:FF:7B:65:C0:D2", essid: "TP-Link_R2D2", mode: "Master",
          channel: 10, quality: 70, auth_mode: Y2Network::WirelessAuthMode::WPA_PSK
        ),
        an_object_having_attributes(
          address: "7E:ED:69:D5:89:A5", essid: "TP-Link_C3PO", mode: "Master",
          channel: 1, quality: 42, auth_mode: Y2Network::WirelessAuthMode::WEP_OPEN
        ),
        an_object_having_attributes(
          address: "68:FF:7B:65:C0:D3", essid: "GUESTS", mode: "Master",
          channel: 10, quality: 30, auth_mode: Y2Network::WirelessAuthMode::NONE
        ),
        an_object_having_attributes(
          address: "02:00:00:00:00:00", essid: "COMPANY", mode: "Master",
          channel: 1, quality: 70, auth_mode: Y2Network::WirelessAuthMode::WPA_EAP
        )
      )
    end

    context "when no wireless networks are found" do
      let(:iwlist) { "" }

      it "returns an empty array" do
        expect(scanner.cells).to be_empty
      end
    end

    context "when listing the wireless cells failed" do
      before do
        allow(Yast::Execute).to receive(:locally!)
          .and_raise(Cheetah::ExecutionFailed.new([], nil, nil, nil))
      end

      it "returns an empty array" do
        expect(scanner.cells).to be_empty
      end
    end
  end
end
