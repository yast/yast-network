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
require "cwm/rspec"

require "y2network/widgets/delete_interface"
require "y2network/interface_config_builder"
require "y2network/virtual_interface"

Yast.import "Lan"

describe Y2Network::Widgets::DeleteInterface do
  subject { described_class.new(table) }

  let(:table) { double("table", value: selected) }
  let(:selected) { "eth0" }
  let(:eth0) { Y2Network::Interface.new("eth0") }
  let(:br0) { Y2Network::VirtualInterface.new("br0", type: Y2Network::InterfaceType::BRIDGE) }
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0]) }
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, br0_conn]) }
  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |c|
      c.name = "eth0"
      c.interface = "eth0"
    end
  end
  let(:br0_conn) do
    Y2Network::ConnectionConfig::Bridge.new.tap do |c|
      c.name = "br0"
      c.interface = "br0"
    end
  end
  let(:config) do
    Y2Network::Config.new(interfaces: interfaces, connections: connections, source: :testing)
  end

  let(:selected) { "eth0" }

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(config)
  end

  include_examples "CWM::PushButton"

  describe "#init" do
    context "when an element is selected" do
      it "does not disable the widget" do
        expect(subject).to_not receive(:disable)
        subject.init
      end
    end

    context "when no element is selected" do
      let(:selected) { nil }

      it "disables the widget" do
        expect(subject).to receive(:disable)
        subject.init
      end
    end
  end

  describe "#handle" do
    context "interface does not have connection config" do
      let(:eth1) { Y2Network::Interface.new("eth1") }
      let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0, eth1]) }
      let(:selected) { "eth1" }

      it "do nothing" do
        expect(config).to_not receive(:delete_interface)
        subject.handle
      end
    end

    context "interface is nfs root" do
      before do
        eth0_conn.startmode = Y2Network::Startmode.create("nfsroot")
      end

      it "asks before deleting" do
        expect(Yast::Popup).to receive(:YesNoHeadline)

        subject.handle
      end
    end

    context "interface is used in another interface" do
      let(:br0_conn) do
        Y2Network::ConnectionConfig::Bridge.new.tap do |c|
          c.name = "br0"
          c.interface = "br0"
          c.ports = ["eth0"]
        end
      end

      it "asks before deleting" do
        expect(Yast2::Popup).to receive(:show).and_return :no

        subject.handle
      end
    end

    it "deletes interface" do
      expect { subject.handle }.to change { config.connections.to_a }
        .from([eth0_conn, br0_conn]).to([br0_conn])
    end
  end
end
