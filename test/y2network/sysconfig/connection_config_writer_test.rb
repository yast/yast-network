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

  let(:conn) do
    instance_double(
      Y2Network::ConnectionConfig::Ethernet,
      interface: "eth0",
      type:      Y2Network::InterfaceType::ETHERNET,
      ip:        ip_config
    )
  end

  let(:old_conn) do
    instance_double(
      Y2Network::ConnectionConfig::Ethernet,
      interface: "eth0",
      type:      Y2Network::InterfaceType::ETHERNET
    )
  end

  let(:ip_config) do
    Y2Network::ConnectionConfig::IPConfig.new(Y2Network::IPAddress.from_string("10.100.0.1/24"))
  end

  let(:file) do
    instance_double(
      CFA::InterfaceFile, save: nil, clean: nil, remove: nil
    )
  end

  describe "#write" do
    let(:handler) do
      instance_double(
        Y2Network::Sysconfig::ConnectionConfigWriters::Ethernet,
        write: nil
      )
    end

    before do
      allow(writer).to receive(:require).and_call_original
      allow(Y2Network::Sysconfig::ConnectionConfigWriters::Ethernet).to receive(:new)
        .and_return(handler)
      allow(CFA::InterfaceFile).to receive(:new).and_return(file)
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

    it "removes the old configuration if given" do
      expect(writer).to receive(:remove).with(old_conn)
      writer.write(conn, old_conn)
    end

    it "does nothing if the connection has not changed" do
      expect(file).to_not receive(:save)
      writer.write(conn, conn)
    end
  end

  describe "#remove" do
    let(:autoinstallation) { false }
    before do
      allow(CFA::InterfaceFile).to receive(:find).and_return(file)
      allow(Yast::Mode).to receive(:auto).and_return(autoinstallation)
    end

    it "removes the configuration file" do
      expect(file).to receive(:remove)
      writer.remove(conn)
    end

    it "removes the hostname" do
      expect(Yast::Host).to receive(:remove_ip).with(conn.ip.address.address.to_s)
      writer.remove(conn)
    end

    context "if no IP address is defined" do
      let(:ip_config) { nil }

      it "does not try to remove the hostname" do
        expect(Yast::Host).to_not receive(:remove_ip)
        writer.remove(conn)
      end
    end

    context "during an autoinstallation" do
      let(:autoinstallation) { true }

      it "does not try to remove the hostname" do
        expect(Yast::Host).to_not receive(:remove_ip)
        writer.remove(conn)
      end
    end
  end
end
