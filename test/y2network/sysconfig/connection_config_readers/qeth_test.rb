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
require "y2network/sysconfig/connection_config_readers/qeth"
require "cfa/interface_file"
require "y2network/boot_protocol"

describe Y2Network::Sysconfig::ConnectionConfigReaders::Qeth do
  subject(:handler) { described_class.new(file) }

  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "eth5" }

  let(:file) do
    CFA::InterfaceFile.find(interface_name).tap(&:load)
  end

  describe "#connection_config" do
    it "returns a qeth connection config object" do
      qeth = handler.connection_config
      expect(qeth.type).to eql(Y2Network::InterfaceType::QETH)
      expect(qeth.interface).to eq("eth5")
      expect(qeth.ip.address).to eq(Y2Network::IPAddress.from_string("192.168.50.1/24"))
      expect(qeth.bootproto).to eq(Y2Network::BootProtocol::STATIC)
    end
  end
end
