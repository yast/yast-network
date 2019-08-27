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
require "y2network/sysconfig/interfaces_writer"
require "y2network/udev_rule"
require "y2network/physical_interface"
require "y2network/interfaces_collection"

describe Y2Network::Sysconfig::InterfacesWriter do
  subject(:writer) { described_class.new }

  describe "#write" do
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0]) }
    let(:eth0) do
      Y2Network::PhysicalInterface.new("eth0").tap { |i| i.renaming_mechanism = renaming_mechanism }
    end
    let(:hardware) do
      instance_double(Y2Network::Hwinfo, busid: "00:1c.0", mac: "01:23:45:67:89:ab", dev_port: "1")
    end
    let(:renaming_mechanism) { nil }

    before do
      allow(Yast::Execute).to receive(:on_target)
      allow(eth0).to receive(:hardware).and_return(hardware)
    end

    context "when the interface is renamed using the MAC" do
      let(:renaming_mechanism) { :mac }

      it "writes a MAC based udev renaming rule" do
        expect(Y2Network::UdevRule).to receive(:write) do |rules|
          expect(rules.first.to_s).to eq(
            "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", " \
            "ATTR{type}==\"1\", ATTR{address}=\"01:23:45:67:89:ab\", NAME=\"eth0\""
          )
        end
        subject.write(interfaces)
      end
    end

    context "when the interface is renamed using the BUS ID" do
      let(:renaming_mechanism) { :bus_id }

      it "writes a BUS ID based udev renaming rule" do
        expect(Y2Network::UdevRule).to receive(:write) do |rules|
          expect(rules.first.to_s).to eq(
            "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", " \
              "ATTR{type}==\"1\", KERNELS=\"00:1c.0\", ATTR{dev_port}=\"1\", NAME=\"eth0\""
          )
        end
        subject.write(interfaces)
      end
    end

    context "when the interface is not renamed" do
      let(:renaming_mechanism) { nil }

      it "does not write a udev rule" do
        expect(Y2Network::UdevRule).to receive(:write) do |rules|
          expect(rules).to be_empty
        end
        subject.write(interfaces)
      end
    end

    it "refreshes udev" do
      expect(Yast::Execute).to receive(:on_target).with("/usr/bin/udevadm", "control", any_args)
      expect(Yast::Execute).to receive(:on_target).with("/usr/bin/udevadm", "trigger", any_args)
      subject.write(interfaces)
    end
  end
end
