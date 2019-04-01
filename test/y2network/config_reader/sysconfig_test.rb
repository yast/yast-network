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
require "y2network/config_reader/sysconfig"

describe Y2Network::ConfigReader::Sysconfig do
  subject(:reader) { described_class.new }

  let(:network_interfaces) do
    instance_double(
      Yast::NetworkInterfacesClass,
      Read: nil,
      List: ["lo", "eth0", "wlan0"]
    )
  end

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

  around { |example| change_scr_root("#{DATA_PATH}/scr_read/", &example) }

  describe "#config" do
    before do
      stub_const("Yast::NetworkInterfaces", network_interfaces)
    end

    it "returns a configuration including network devices" do
      config = reader.config
      expect(config.interfaces.map(&:name)).to eq(["lo", "eth0", "wlan0"])
    end

    it "returns a configuration including routes" do
      config = reader.config
      expect(config.routing.routes.size).to eq(4)
    end

    it "sets the config source to :sysconfig" do
      config = reader.config
      expect(config.source).to eq(:sysconfig)
    end

    context "when gateway is missing" do
      let(:gateway) { "-" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "sets the gateway to nil" do
        config = reader.config
        route = config.routing.routes.first
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
        config = reader.config
        route = config.routing.routes.first
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
        config = reader.config
        route = config.routing.routes.first
        expect(route.to).to eq(:default)
      end
    end
  end

  describe "#forward_ipv4?" do
    it "returns true when IPv4 forwarding is allowed" do
      expect(reader.send(:forward_ipv4?)).to be true
    end
  end

  describe "#forward_ipv6?" do
    it "returns false when IPv6 forwarding is disabled" do
      expect(reader.send(:forward_ipv6?)).to be false
    end
  end
end
