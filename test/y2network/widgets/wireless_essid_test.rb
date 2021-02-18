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
require "cwm/rspec"

require "y2network/widgets/wireless_essid"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::WirelessEssid do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"
end

describe Y2Network::Widgets::WirelessScan do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  let(:essid) { Y2Network::Widgets::WirelessEssidName.new(builder) }
  let(:installed) { true }
  let(:initial_stage) { false }
  let(:available_networks) { ["YaST", "Guests"] }
  subject { described_class.new(builder, update: essid) }

  before do
    allow(subject).to receive(:scan_supported?).and_return(installed)
    allow(Yast::Package).to receive(:Installed).and_return(installed)
    allow(Yast::Stage).to receive(:initial).and_return(initial_stage)
    allow(subject).to receive(:fetch_essid_list).and_return(available_networks)
    allow(essid).to receive(:update_essid_list)
  end

  describe "#init" do
    before do
      allow(subject).to receive(:present?).and_return(iface_present?)
    end

    context "when the interface exists" do
      let(:iface_present?) { true }

      it "does not disable the button" do
        expect(subject).to_not receive(:disable)
        subject.init
      end
    end

    context "when the interface does not exist" do
      let(:iface_present?) { false }

      it "disables the button" do
        expect(subject).to receive(:disable)
        subject.init
      end
    end
  end

  describe "#handle" do
    let(:networks_dialog) do
      instance_double(Y2Network::Dialogs::WirelessNetworks, run: nil)
    end

    before do
      allow(Y2Network::Dialogs::WirelessNetworks).to receive(:new)
        .and_return(networks_dialog)
    end

    context "when the package for scanning wireless networks is not installed" do
      let(:installed) { false }

      before do
        allow(subject).to receive(:scan_supported?).and_call_original
      end

      it "tries to install it" do
        expect(Yast::Package).to receive(:Install).and_return(true)
        subject.handle
      end

      context "and failed installing the missing package" do
        it "returns without scanning the available network" do
          allow(Yast::Package).to receive(:Install).and_return(false)
          expect(Yast::Popup).to receive(:Error).with(/was not installed/)
          expect(subject).to_not receive(:fetch_essid_list)

          expect(subject.handle).to eql(nil)
        end
      end
    end

    context "when the package for scanning wireless networks is installed" do
      it "scans the list of available essids" do
        expect(subject).to receive(:fetch_essid_list).and_return(available_networks)
        subject.handle
      end

      it "updates the widget with the list of the available essids with the obtained one" do
        expect(essid).to receive(:update_essid_list).with(available_networks)
        subject.handle
      end
    end
  end
end
