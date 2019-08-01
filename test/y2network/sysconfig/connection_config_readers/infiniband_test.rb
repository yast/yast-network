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

require_relative "../../../test_helper"
require "y2network/sysconfig/connection_config_readers/infiniband"
require "y2network/sysconfig/interface_file"

describe Y2Network::Sysconfig::ConnectionConfigReaders::Infiniband do
  subject(:handler) { described_class.new(file) }

  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "ib0" }
  let(:file) do
    Y2Network::Sysconfig::InterfaceFile.find(interface_name).tap(&:load)
  end

  describe "#connection_config" do
    let(:ip_address) { Y2Network::IPAddress.from_string("192.168.20.1/24") }

    it "returns a infiniband connection config object" do
      infiniband_conn = handler.connection_config
      expect(infiniband_conn.interface).to eq("ib0")
      expect(infiniband_conn.ipoib_mode).to eq(Y2Network::IpoibMode::DATAGRAM)
      expect(infiniband_conn.all_ips.map(&:address)).to eq([ip_address])
      expect(infiniband_conn.bootproto).to eq(Y2Network::BootProtocol::STATIC)
    end
  end
end
