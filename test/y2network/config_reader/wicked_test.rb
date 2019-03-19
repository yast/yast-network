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
require "y2network/config_reader/wicked"

describe Y2Network::ConfigReader::Wicked do
  subject(:reader) { described_class.new }

  let(:network_interfaces) do
    instance_double(
      Yast::NetworkInterfacesClass,
      Read: nil,
      List: ["lo", "eth0", "wlan0"]
    )
  end

  describe "" do
    before do
      stub_const("Yast::NetworkInterfaces", network_interfaces)
    end

    it "returns a configuration including network devices" do
      config = reader.config
      expect(config.interfaces.map(&:name)).to eq(["lo", "eth0", "wlan0"])
    end
  end
end
