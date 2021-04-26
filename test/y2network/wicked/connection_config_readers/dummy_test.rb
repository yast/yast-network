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
require "y2network/wicked/connection_config_readers/dummy"
require "cfa/interface_file"
require "y2issues"

describe Y2Network::Wicked::ConnectionConfigReaders::Dummy do
  subject(:handler) { described_class.new(file, issues_list) }

  let(:issues_list) { Y2Issues::List.new }
  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "dummy0" }
  let(:file) do
    CFA::InterfaceFile.find(interface_name).tap(&:load)
  end

  describe "#connection_config" do
    let(:ip_address) { Y2Network::IPAddress.from_string("192.168.100.150/24") }

    it "returns a dummy connection config object" do
      dummy_conn = handler.connection_config
      expect(dummy_conn.interface).to eq("dummy0")
      expect(dummy_conn.ip.address).to eq(ip_address)
      expect(dummy_conn.bootproto).to eq(Y2Network::BootProtocol::STATIC)
    end
  end
end
