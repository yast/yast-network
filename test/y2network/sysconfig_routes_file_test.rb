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

require_relative "../test_helper"

require "y2network/sysconfig_routes_file"

describe Y2Network::SysconfigRoutesFile do
  subject(:file) { described_class.new(path) }

  let(:scr_route) do
    {
      "destination" => destination,
      "device"      => "eth0",
      "gateway"     => gateway,
      "netmask"     => netmask
    }
  end
  let(:destination) { "192.168.122.1" }
  let(:gateway)     { "192.168.122.1" }
  let(:netmask)     { "255.255.255.0" }

  around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

  describe "#load" do
    let(:path) { "/etc/sysconfig/network/routes" }

    it "loads the routes from the given file" do
      file.load
      expect(file.routes.size).to eq(3)
    end

    context "when gateway is missing" do
      let(:gateway) { "-" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "sets the gateway to nil" do
        file.load
        route = file.routes.first
        expect(route.gateway).to be_nil
      end
    end

    context "when there is no netmask" do
      let(:netmask) { "-" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "does not set destination netmask" do
        file.load
        route = file.routes.first
        expect(route.to).to eq(IPAddr.new("192.168.122.1/255.255.255.255"))
      end
    end

    context "when there is no destination" do
      let(:destination) { "default" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "considers the route to be the default one" do
        file.load
        route = file.routes.first
        expect(route.to).to eq(:default)
      end
    end
  end
end
