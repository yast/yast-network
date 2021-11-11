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

require "y2network/widgets/interfaces_table"
require "y2network/virtual_interface"

Yast.import "Lan"

describe Y2Network::Widgets::InterfacesTable do
  subject { described_class.new(description) }

  let(:description) { double(:value= => nil) }

  let(:eth0) do
    instance_double(Y2Network::Interface, name: "eth0", hardware: hwinfo, old_name: "eth1")
  end
  let(:br0) do
    instance_double(Y2Network::VirtualInterface, name: "br0", hardware: nil, old_name: nil)
  end
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, br0]) }
  let(:hwinfo) do
    instance_double(Y2Network::Hwinfo, link: link, mac: mac, busid: busid,
      exists?: exists?, present?: true, description: "Cool device", name: "Cool device")
  end

  let(:mac) { "01:23:45:67:89:ab" }
  let(:busid) { "0000:04:00.0" }
  let(:link) { false }
  let(:exists?) { true }
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn, br0_conn]) }
  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap { |c| c.name = "eth0" }
  end
  let(:br0_conn) do
    Y2Network::ConnectionConfig::Bridge.new.tap { |c| c.name = "br0" }
  end

  let(:qeth_0700) do
    instance_double(Y2Network::S390GroupDevice, type: "qeth", hardware: hwinfo_0700,
      id: "0.0.0700:0.0.0701:0.0.0702", online?: false)
  end

  let(:hwinfo_0700) do
    instance_double(Y2Network::Hwinfo, present?:    true,
                                       description: "OSA Express Network card (0.0.0700)")
  end

  let(:s390_devices) do
    Y2Network::S390GroupDevicesCollection.new([qeth_0700])
  end

  before do
    allow(Yast::Lan).to receive(:yast_config)
      .and_return(double(interfaces: interfaces, connections: connections, s390_devices:
                  s390_devices))
    allow(Yast::UI).to receive(:QueryWidget).and_return([])
    allow(subject).to receive(:value).and_return("eth0")
  end

  include_examples "CWM::Table"

  describe "#items" do
    context "when it includes a configured device" do
      it "includes the connection device name" do
        expect(subject.items).to include(a_collection_including(/eth0/))
      end

      context "and the device is named by user" do
        let(:eth0_conn) do
          Y2Network::ConnectionConfig::Ethernet.new.tap do |c|
            c.name = "eth0"
            c.description = "Custom description"
          end
        end

        it "includes its custom device name" do
          expect(subject.items).to include(a_collection_including(/Custom description/))
        end
      end
    end

    context "and the device is not configured" do
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }

      it "shows the hwinfo interface description if present or the interface name if not" do
        expect(subject.items).to include(a_collection_including(/Cool device/, /eth0/),
          a_collection_including(/br0/), a_collection_including(/OSA Express Network card/))
      end
    end
  end

  describe "#handle" do
    it "updates the description" do
      expect(description).to receive(:value=)
      subject.handle
    end

    it "includes the MAC address in the description" do
      expect(description).to receive(:value=).with(/MAC/)
      subject.handle
    end

    context "when there is no MAC address" do
      let(:mac) { nil }

      it "does not include the MAC in the description" do
        expect(description).to receive(:value=) do |text|
          expect(text).to_not include("MAC")
        end
        subject.handle
      end
    end

    it "includes the Bus ID address in the description" do
      expect(description).to receive(:value=).with(/BusID/)
      subject.handle
    end

    context "when there is no Bus ID" do
      let(:busid) { nil }

      it "does not include the Bus ID in the description" do
        expect(description).to receive(:value=) do |text|
          expect(text).to_not include("BusID")
        end
        subject.handle
      end
    end

    context "when there is no hardware information" do
      let(:exists?) { false }

      it "sets the description with 'no hardware information' warning" do
        expect(description).to receive(:value=).with(/No hardware information/)
        subject.handle
      end
    end

    context "when there is no link" do
      let(:link) { false }

      it "sets includes a 'Not connected' text" do
        expect(description).to receive(:value=).with(/Not connected/)
        subject.handle
      end
    end

    context "when the device is configured" do
      it "includes its device name in the description" do
        expect(description).to receive(:value=).with(/Device Name: eth0/)
        subject.handle
      end
    end

    context "when the device is not configured" do
      let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }

      it "includes a warning in the description" do
        expect(description).to receive(:value=).with(/The device is not configured./)
        subject.handle
      end
    end
  end
end
