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

require "y2network/sysconfig/connection_config_writers/eth"
require "y2network/sysconfig/interface_file"

describe Y2Network::Sysconfig::ConnectionConfigWriters::Eth do
  subject(:writer) { described_class.new(file) }

  let(:address) { IPAddr.new("192.168.122.1") }
  let(:conn) do
    instance_double(
      Y2Network::ConnectionConfig::Ethernet,
      interface: "eth0", bootproto: :static, ip_address: address, startmode: :auto
    )
  end
  let(:file) do
    instance_double(Y2Network::Sysconfig::InterfaceFile)
  end

  before do
    allow(Y2Network::Sysconfig::InterfaceFile)
      .to receive(:new).and_return(file)
  end

  describe "#write" do
    it "updates ethernet related properties" do
      expect(file).to receive(:bootproto=).with(:static)
      expect(file).to receive(:ipaddr=).with(address)
      expect(file).to receive(:startmode=).with(:auto)
      writer.write(conn)
    end
  end
end
