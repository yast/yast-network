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

require "y2network/config_reader/sysconfig_routes_reader"

describe Y2Network::ConfigReader::SysconfigRoutesReader do
  subject(:reader) { described_class.new }

  describe "#config" do
    old_SCR = Yast::WFM.SCRGetDefault

    def agent_stub_scr_read(agent)
      new_SCR = Yast::WFM.SCROpen("chroot=#{DATA_PATH}/scr_read:scr", false)

      Yast::WFM.SCRSetDefault(new_SCR)
      info = Yast::SCR.Read(agent)

      mock_path(agent, info)
    end

    before(:each) do
      agent_stub_scr_read(".routes")
    end

    after(:each) do
      Yast::WFM.SCRSetDefault(old_SCR)
    end

    it "returns a RoutingTable with routes" do
      routing_table = reader.config

      expect(routing_table).to be_instance_of Y2Network::RoutingTable
      expect(routing_table.routes).not_to be_empty
    end

    it "contains default gw definition" do
      expect(reader.config.routes.any? { |r| r.default? }).to be_truthy
    end

    it "accepts prefix from gateway field" do
      route = reader.config.routes.find { |r| r.to == "10.192.0.0" }

      expect(route.to.prefix).to eql 10
    end

    it "stores device when set" do
      expect(reader.config.routes.any? { |r| r.interface.name == "eth0" }).to be_truthy
    end
  end
end
