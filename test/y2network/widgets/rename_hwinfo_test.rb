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

require "y2network/widgets/rename_hwinfo"
require "y2network/interface_config_builder"
require "y2network/physical_interface"

describe Y2Network::Widgets::RenameHwinfo do
  subject { described_class.new(builder) }

  let(:builder) do
    instance_double(Y2Network::InterfaceConfigBuilder, interface: interface, renaming_mechanism: mechanism)
  end

  let(:interface) { Y2Network::PhysicalInterface.new("eth0") }
  let(:hwinfo) { Y2Network::Hwinfo.new(mac: "01:23:45:67:89:ab", busid: "0000:08:00.0") }
  let(:mechanism) { :mac }

  include_examples "CWM::CustomWidget"

  before do
    allow(interface).to receive(:hardware).and_return(hwinfo)
    allow(subject).to receive(:current_value).and_return(mechanism)
  end

  describe "#result" do
    before do
      subject.init
      subject.store
    end

    context "when the MAC is selected as renaming method" do
      it "returns :mac as the renaming mechanism" do
        selected_mechanism, = subject.result
        expect(selected_mechanism).to eq(:mac)
      end
    end

    context "when the BUS ID is selected as renaming method" do
      let(:mechanism) { :bus_id }

      it "returns :bus_id as the renaming mechanism" do
        selected_mechanism, = subject.result
        expect(selected_mechanism).to eq(:bus_id)
      end
    end
  end
end
