# Copyright (c) [2021] SUSE LLC
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
require_relative "../../support/config_writer_examples"
require "y2network/network_manager/config_writer"
require "y2network/config"
require "y2network/connection_configs_collection"
require "y2network/interface"
require "y2network/interfaces_collection"
require "y2network/ip_address"
require "y2network/boot_protocol"
require "y2network/route"
require "y2network/routing"
require "y2network/routing_table"
require "cfa/nm_connection"

describe Y2Network::NetworkManager::ConfigWriter do
  subject(:writer) { described_class.new }

  include_examples "ConfigWriter"

  describe "#write" do
    let(:old_config) do
      Y2Network::Config.new(
        source:      :network_manager,
        interfaces:  Y2Network::InterfacesCollection.new([eth0]),
        connections: Y2Network::ConnectionConfigsCollection.new([])
      )
    end

    let(:config) do
      old_config.copy.tap do |cfg|
        cfg.add_or_update_connection_config(eth0_conn)
        cfg.dns = dns
        cfg.routing = routing
      end
    end

    let(:eth0_conn) do
      Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
        conn.interface = "eth0"
        conn.name = "eth0"
        conn.bootproto = Y2Network::BootProtocol::DHCP
        conn.ip = ip
      end
    end

    let(:routes) { [] }
    let(:gateway) { IPAddr.new("192.168.122.1") }

    let(:eth0_route) do
      Y2Network::Route.new(
        to:        :default,
        interface: eth0,
        gateway:   gateway
      )
    end

    let(:default_route) do
      Y2Network::Route.new(
        to:      :default,
        gateway: gateway
      )
    end

    let(:routing) do
      Y2Network::Routing.new(
        tables: [Y2Network::RoutingTable.new(routes)]
      )
    end

    let(:nameserver1) { IPAddr.new("192.168.1.1") }
    let(:nameserver2) { IPAddr.new("10.0.0.1") }
    let(:nameserver3) { IPAddr.new("2000:e1dd:f002:0120:0000:0000:0000:0001") }
    let(:nameserver4) { IPAddr.new("2000:e1dd:f002:0120:0000:0000:0000:0002") }

    let(:dns) do
      Y2Network::DNS.new(
        nameservers: [
          nameserver1, nameserver2, nameserver3, nameserver4
        ]
      )
    end

    let(:ip) do
      address = Y2Network::IPAddress.from_string("192.168.122.2/24")
      Y2Network::ConnectionConfig::IPConfig.new(address)
    end
    let(:eth0) { Y2Network::Interface.new("eth0") }

    let(:conn_config_writer) { Y2Network::NetworkManager::ConnectionConfigWriter.new }

    let(:file_path) { File.join(DATA_PATH, "eth0_test.nmconnection") }

    let(:file) { CFA::NmConnection.new(file_path) }

    before do
      allow(CFA::NmConnection).to receive(:for).and_return(file)
      allow(Y2Network::NetworkManager::ConnectionConfigWriter).to receive(:new)
        .and_return(conn_config_writer)
      allow(writer).to receive(:write_drivers)
      allow(writer).to receive(:write_hostname)
    end

    after { FileUtils.rm_f(file_path) }

    it "writes connections configuration" do
      options = { routes: [], parent: nil }
      expect(conn_config_writer).to receive(:write).with(eth0_conn, nil, options)
      writer.write(config)
    end

    context "when there is some device route to be configured" do
      let(:routes) { [eth0_route] }

      context "and it contains a gateway" do
        it "writes the connection gateway" do
          writer.write(config)
          expect(file.ipv4["gateway"]).to eq("192.168.122.1")
        end
      end

      context "and it does not contain a gateway" do
        let(:eth0_route) do
          Y2Network::Route.new(
            to:        :default,
            interface: eth0
          )
        end

        it "does not write any gateway" do
          writer.write(config)
          expect(file.ipv4["gateway"]).to be_nil
        end
      end
    end

    context "when there is some global route to be configured" do
      let(:routes) { [default_route] }

      context "and it contains a gateway" do
        context "and the connections are configured by DHCP" do
          it "does not write any gateway" do
            writer.write(config)
            expect(file.ipv4["gateway"]).to be_nil
          end
        end

        context "and there is some connection configured with an static IP" do
          let(:eth0_conn) do
            Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
              conn.interface = "eth0"
              conn.name = "eth0"
              conn.bootproto = Y2Network::BootProtocol::STATIC
              conn.ip = ip
            end
          end

          context "when the gateway does not belongs to the same network than the connection" do
            let(:gateway) { IPAddr.new("192.168.1.1") }

            it "does not write any gateway" do
              writer.write(config)
              expect(file.ipv4["gateway"]).to be_nil
            end
          end

          context "when the gateway belongs to the same network than the connection" do
            it "writes the connection gateway" do
              writer.write(config)
              expect(file.ipv4["gateway"]).to eq("192.168.122.1")
            end
          end
        end
      end

      context "and it does not contain a gateway" do
        it "does not write any gateway" do
          writer.write(config)
          expect(file.ipv4["gateway"]).to be_nil
        end
      end
    end

    context "writes DNS configuration" do
      context "when a connection has static configuration" do
        let(:eth0_conn) do
          Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
            conn.interface = "eth0"
            conn.name = "eth0"
            conn.bootproto = Y2Network::BootProtocol::STATIC
            conn.ip = ip
          end
        end

        it "includes DNS configuration in the configuration file" do
          writer.write(config)
          expect(file.ipv4["dns"]).to eq("#{nameserver1};#{nameserver2}")
          expect(file.ipv6["dns"]).to eq("#{nameserver3};#{nameserver4}")
        end
      end
    end
  end
end
