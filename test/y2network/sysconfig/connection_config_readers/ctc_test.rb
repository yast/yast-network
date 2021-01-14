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
require "y2network/sysconfig/connection_config_readers/ctc"
require "cfa/interface_file"
require "y2network/boot_protocol"

describe Y2Network::Sysconfig::ConnectionConfigReaders::Ctc do
  subject(:handler) { described_class.new(file) }

  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "ctc0" }

  let(:file) do
    CFA::InterfaceFile.find(interface_name).tap(&:load)
  end

  describe "#connection_config" do
    it "returns a ctc connection config object" do
      ctc = handler.connection_config
      expect(ctc.type).to eql(Y2Network::InterfaceType::CTC)
      expect(ctc.interface).to eq("ctc0")
      expect(ctc.ip.address).to eq(Y2Network::IPAddress.from_string("192.168.20.50/24"))
      expect(ctc.bootproto).to eq(Y2Network::BootProtocol::STATIC)
    end
  end
end
