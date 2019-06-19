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
require "y2network/sysconfig/connection_config_reader_handlers/eth"
require "y2network/sysconfig/interface_file"

describe Y2Network::Sysconfig::ConnectionConfigReaderHandlers::Eth do
  subject(:handler) { described_class.new(file) }

  let(:address) { IPAddr.new("192.168.122.1") }

  let(:file) do
    instance_double(
      Y2Network::Sysconfig::InterfaceFile,
      name:       "eth0",
      bootproto:  :static,
      ip_address: address
    )
  end

  describe "#connection_config" do
    it "returns an ethernet connection config object" do
      eth = handler.connection_config
      expect(eth.interface).to eq("eth0")
      expect(eth.bootproto).to eq(:static)
      expect(eth.ip_address).to eq(address)
    end
  end
end
