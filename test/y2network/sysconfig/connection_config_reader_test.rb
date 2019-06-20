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

require "y2network/sysconfig/connection_config_reader"
require "y2network/sysconfig/connection_config_readers/wlan"
require "y2network/physical_interface"

describe Y2Network::Sysconfig::ConnectionConfigReader do
  subject(:reader) { described_class.new }

  describe "#read" do
    let(:interface) { instance_double(Y2Network::PhysicalInterface, name: "wlan0", type: :wlan) }
    let(:connection_config) { double("connection_config") }
    let(:handler) do
      instance_double(
        Y2Network::Sysconfig::ConnectionConfigReaders::Wlan,
        connection_config: connection_config
      )
    end

    before do
      allow(reader).to receive(:require).and_call_original
      allow(Y2Network::Sysconfig::ConnectionConfigReaders::Wlan)
        .to receive(:new).and_return(handler)
    end

    it "uses the appropiate handler" do
      expect(reader).to receive(:require)
        .with("y2network/sysconfig/connection_config_reader_handlers/wlan")
      conn = reader.read(interface, :wlan)
      expect(conn).to be(connection_config)
    end

    xcontext "when the interface type is unknown" do
      let(:interface) { instance_double(Y2Network::PhysicalInterface, type: :foo) }

      it "returns nil" do
        expect(reader.read(interface, :wlan)).to be_nil
      end
    end
  end
end
