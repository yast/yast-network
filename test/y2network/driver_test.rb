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

require "y2network/driver"

describe Y2Network::Driver do
  subject(:driver) { described_class.new("virtio_net", "debug=16") }

  describe ".from_system" do
    before do
      allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".modules.options.virtio_net"))
        .and_return("csum" => "1")
    end

    it "reads the parameters from the underlying system" do
      driver = described_class.from_system("virtio_net")
      expect(driver.params).to eq("csum=1")
    end
  end

  describe ".write_options" do
    it "writes the parameters to the underlying system" do
      expect(driver).to receive(:write_options)
      expect(Yast::SCR).to receive(:Write)
        .with(Yast::Path.new(".modules"), nil)
      described_class.write_options([driver])
    end
  end

  describe "#write_options" do
    it "writes options to the underlying system" do
      options = { "debug" => "16" }
      expect(Yast::SCR).to receive(:Write)
        .with(Yast::Path.new(".modules.options.virtio_net"), options)
      driver.write_options
    end
  end
end
