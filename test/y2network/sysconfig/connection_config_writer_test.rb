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

require "y2network/sysconfig/connection_config_writer"
require "y2network/sysconfig/connection_config_writers/ethernet"
require "y2network/connection_config/ethernet"
require "y2network/interface_type"

describe Y2Network::Sysconfig::ConnectionConfigWriter do
  subject(:writer) { described_class.new }

  describe "#write" do
    let(:handler) do
      instance_double(
        Y2Network::Sysconfig::ConnectionConfigWriters::Ethernet,
        write: nil
      )
    end

    let(:conn) do
      instance_double(
        Y2Network::ConnectionConfig::Ethernet,
        interface: "eth0",
        type:      Y2Network::InterfaceType::ETHERNET
      )
    end

    let(:file) do
      instance_double(
        Y2Network::Sysconfig::InterfaceFile, save: nil, clean: nil
      )
    end

    before do
      allow(writer).to receive(:require).and_call_original
      allow(Y2Network::Sysconfig::ConnectionConfigWriters::Ethernet).to receive(:new)
        .and_return(handler)
      allow(Y2Network::Sysconfig::InterfaceFile).to receive(:new).and_return(file)
    end

    it "uses the appropiate handler" do
      expect(writer).to receive(:require).and_return(handler)
      expect(handler).to receive(:write).with(conn)
      writer.write(conn)
    end

    it "cleans old values and writes new ones" do
      expect(file).to receive(:clean)
      expect(file).to receive(:save)
      writer.write(conn)
    end
  end
end
