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
require "y2network/hwinfo"

describe Y2Network::Hwinfo do
  subject(:hwinfo) { described_class.new(name: interface_name) }

  let(:hardware) do
    YAML.load_file(File.join(DATA_PATH, "hardware.yml"))
  end

  let(:interface_name) { "enp1s0" }

  before do
    allow(Yast::LanItems).to receive(:Hardware).and_return(hardware)
  end

  describe "#exists?" do
    context "when the device exists" do
      it "returns true" do
        expect(hwinfo.exists?).to eq(true)
      end
    end

    context "when the device does not exist" do
      let(:interface_name) { "missing" }

      it "returns false" do
        expect(hwinfo.exists?).to eq(false)
      end
    end
  end

  describe "#modules_names" do
    it "returns the list of kernel modules names" do
      expect(hwinfo.modules_names).to eq(["virtio_net"])
    end
  end
end
