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
require "y2network/config_writer/sysconfig"
require "y2network/config"
require "y2network/interface"
require "y2network/route"
require "y2network/routing_table"

describe Y2Network::ConfigWriter::Sysconfig do
  subject(:writer) { described_class.new }

  describe "#write" do
    let(:config) do
      Y2Network::Config.new(
        interfaces: [eth0],
        routing_tables: [routing_table]
      )
    end

    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:route) do
      Y2Network::Route.new(
        to: IPAddr.new("10.0.0.2/8"),
        interface: eth0,
        gateway: IPAddr.new("192.168.122.1")
      )
    end
    let(:routing_table) { Y2Network::RoutingTable.new([route]) }

    it "imports defined routes using placeholders" do
      expect(Yast::Routing).to receive(:Import).with(
        "routes" => [
          { "destination" => "10.0.0.0", "device" => "eth0",
            "gateway" => "192.168.122.1", "netmask" => "255.0.0.0" }
        ]
      )
      writer.write(config)
    end

    context "when routes elements are not defined" do
      let(:route) do
        Y2Network::Route.new(to: :default, interface: :any)
      end

      it "imports defined routes using placeholders" do
        expect(Yast::Routing).to receive(:Import).with(
          "routes" => [
            { "destination" => "-", "device" => "-", "gateway" => "-", "netmask" => "-" }
          ]
        )
        writer.write(config)
      end
    end
  end
end
