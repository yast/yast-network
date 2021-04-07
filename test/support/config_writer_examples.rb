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

require_relative "../test_helper"

require "y2network/config_writers/hostname_writer"
require "y2network/config_writers/dns_writer"
require "y2network/connection_configs_collection"
require "y2network/interfaces_collection"
require "y2network/hostname"
require "y2network/boot_protocol"

RSpec.shared_examples "ConfigWriter" do
  subject(:writer) { described_class.new }

  let(:hostname_writer) { instance_double(Y2Network::ConfigWriters::HostnameWriter, write: nil) }
  let(:dns_writer) { instance_double(Y2Network::ConfigWriters::DNSWriter, write: nil) }
  let(:interfaces_writer) do
    instance_double(Y2Network::ConfigWriters::InterfacesWriter, write: nil)
  end

  let(:old_config) do
    Y2Network::Config.new(
      interfaces:  Y2Network::InterfacesCollection.new([enp1s0]),
      connections: Y2Network::ConnectionConfigsCollection.new([]),
      source:      :testing,
      hostname:    old_hostname
    )
  end

  let(:enp1s0) { Y2Network::PhysicalInterface.new("enp1s0", hardware: hwinfo) }
  let(:hwinfo) { Y2Network::Hwinfo.new(mac: "00:11:22:33:44:55") }

  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth0"
      conn.name = "eth0"
      conn.bootproto = Y2Network::BootProtocol::DHCP
    end
  end

  let(:old_hostname) { Y2Network::Hostname.new(static: "old_hostname") }
  let(:hostname) { Y2Network::Hostname.new(static: "new_hostname") }

  let(:config) do
    old_config.copy.tap do |cfg|
      cfg.rename_interface("enp1s0", "eth0", :mac)
      cfg.add_or_update_connection_config(eth0_conn)
      cfg.hostname = hostname
    end
  end

  let(:sysctl_config_file) do
    CFA::SysctlConfig.new do |f|
      f.forward_ipv4 = false
      f.forward_ipv6 = false
    end
  end

  before do
    allow(Yast::Host).to receive(:Write)
    allow(Yast::SCR).to receive(:Write)
    allow(Y2Network::ConfigWriters::InterfacesWriter).to receive(:new)
      .and_return(interfaces_writer)
    allow(Y2Network::ConfigWriters::DNSWriter).to receive(:new)
      .and_return(dns_writer)
    allow(Y2Network::ConfigWriters::HostnameWriter).to receive(:new)
      .and_return(hostname_writer)
    allow(CFA::SysctlConfig).to receive(:new).and_return(sysctl_config_file)
    allow(sysctl_config_file).to receive(:load)
    allow(sysctl_config_file).to receive(:save)
  end

  describe "#write" do
    it "writes DNS configuration" do
      expect(dns_writer).to receive(:write).with(config.dns, old_config.dns)
      writer.write(config, old_config, only: [:dns])
    end

    it "writes the hostname" do
      expect(hostname_writer).to receive(:write)
        .with(hostname, old_hostname)
      writer.write(config, old_config, only: [:hostname])
    end

    it "writes /etc/hosts changes" do
      expect(Yast::Host).to receive(:Write).with(gui: false)
      writer.write(config, only: [:dns])
    end
  end

  xcontext "When IPv4 forwarding is set" do
    let(:forward_ipv4) { true }

    it "writes IP forwarding setup for IPv4" do
      expect(sysctl_config_file).to receive(:forward_ipv4=).with(true).and_call_original
      expect(sysctl_config_file).to receive(:forward_ipv6=).with(false).and_call_original
      expect(sysctl_config_file).to receive(:save)
      writer.write(config, only: [:routing])
    end
  end

  xcontext "When IPv6 forwarding is set" do
    let(:forward_ipv6) { true }

    it "writes IP forwarding setup for IPv6" do
      expect(sysctl_config_file).to receive(:forward_ipv4=).with(false).and_call_original
      expect(sysctl_config_file).to receive(:forward_ipv6=).with(true).and_call_original
      expect(sysctl_config_file).to receive(:save)

      writer.write(config, only: [:routing])
    end
  end

  it "writes interfaces configurations" do
    expect(interfaces_writer).to receive(:write).with(config.interfaces)
    writer.write(config, only: [:interfaces])
  end
end
