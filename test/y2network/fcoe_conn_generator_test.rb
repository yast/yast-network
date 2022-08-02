#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
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
require "y2network/fcoe_conn_generator"

describe Y2Network::FcoeConnGenerator do
  let(:generator) { described_class.new(config) }
  let(:config) do
    Y2Network::Config.new(interfaces: interfaces, connections: connections, source: :testing)
  end
  before do
    Yast::Lan.add_config(:yast, config)
  end
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }
  let(:interfaces) { Y2Network::InterfacesCollection.new([]) }
  let(:netcards) do
    [
      {
        "auto_vlan"      => "yes",
        "cfg_device"     => "",
        "dcb_capable"    => "no",
        "dcb_required"   => "no",
        "dev_name"       => "eth1",
        "driver"         => "fcoe",
        "device"         => "TEST Ethernet Controller",
        "fcoe_enable"    => "yes",
        "fcoe_vlan"      => "not configured",
        "mac_addr"       => "08:00:27:11:64:e4",
        "vlan_interface" => "300"
      },
      {
        "auto_vlan"      => "no",
        "cfg_device"     => "eth1.400",
        "dcb_capable"    => "no",
        "dcb_required"   => "yes",
        "driver"         => "fcoe",
        "dev_name"       => "eth1",
        "device"         => "TEST Ethernet Controller",
        "fcoe_enable"    => "yes",
        "fcoe_vlan"      => "eth1.400",
        "mac_addr"       => "08:00:27:11:64:e4",
        "vlan_interface" => "400"
      },
      {
        "auto_vlan"      => "yes",
        "cfg_device"     => "",
        "dcb_capable"    => "no",
        "dcb_required"   => "no",
        "dev_name"       => "eth2",
        "driver"         => "bnx2x",
        "device"         => "Intel PRO/1000 MT Desktop Adapter",
        "fcoe_enable"    => "yes",
        "fcoe_vlan"      => "not configured",
        "mac_addr"       => "08:23:27:99:64:78",
        "vlan_interface" => "200",
        "fcoe_flag"      => true,
        "iscsi_flag"     => false,
        "storage_only"   => true
      }
    ]
  end

  describe ".update_connections_for" do
    let(:device) { netcards[1] }

    it "adds or updates the parent device and FCoE VLAN connection for the given device" do
      expect(config.connections.size).to eql(0)
      generator.update_connections_for(device)
      expect(config.connections.size).to eql(2)
    end

    context "when it adds the new connection for the etherdevice" do
      let(:conn) { config.connections.by_name(device.fetch("dev_name")) }

      before do
        generator.update_connections_for(device)
      end

      it "sets the connection STARTMODE to 'nfsroot'" do
        expect(conn.startmode.to_s).to eql("nfsroot")
      end

      it "sets the connection BOOTPROTO to 'static'" do
        expect(conn.bootproto&.name).to eql("static")
      end
    end

    context "when it adds the new connection for FCoE VLAN" do
      let(:conn) { config.connections.by_name(device.fetch("fcoe_vlan")) }

      before do
        generator.update_connections_for(device)
      end

      it "sets the parent device" do
        expect(conn.parent_device).to eq("eth1")
      end

      it "sets the VLAN id" do
        expect(conn.vlan_id).to eq(400)
      end

      it "sets the connection STARTMODE to 'nfsroot'" do
        expect(conn.startmode.to_s).to eql("nfsroot")
      end

      it "sets the connection BOOTPROTO to 'static'" do
        expect(conn.bootproto&.name).to eql("static")
      end
    end
  end
end
