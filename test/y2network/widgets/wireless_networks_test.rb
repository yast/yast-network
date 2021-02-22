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

require_relative "../../test_helper"
require "y2network/widgets/wireless_networks"
require "y2network/wireless_network"
require "cwm/rspec"

describe Y2Network::Widgets::WirelessNetworks do
  include_examples "CWM::CustomWidget"

  describe "#update" do
    let(:network) do
      Y2Network::WirelessNetwork.new(
        essid: "MY_WIFI", mode: "Master", channel: 10, rate: ["54 Mb/s"],
        quality: 70, security: []
      )
    end

    it "refreshes the list of networks" do
      expect(subject).to receive(:change_items) do |args|
        expect(args).to eq(
          [["MY_WIFI", "MY_WIFI", "Master", 10, "54 Mbit/s", 70, "WPA2"]]
        )
      end
      subject.update([network])
    end

    context "when a network was alreay selected" do
      before do
        allow(Yast::UI).to receive(:QueryWidget)
          .with(Id(subject.widget_id), :SelectedItems)
          .and_return("MY_WIFI")
      end

      it "keeps the selection" do
        expect(subject).to receive(:value=).with("MY_WIFI")
        subject.update([network])
      end
    end
  end
end
