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
require "tmpdir"

describe Y2Network::Sysconfig::InterfacesWriter do
  let(:reload) { false }
  subject(:writer) { described_class.new(reload: reload) }

  describe "#write" do
    let(:interfaces) { Y2Network::InterfacesCollection.new([eth0]) }
    let(:eth0) do
      Y2Network::PhysicalInterface.new("eth0", hardware: hardware).tap do |i|
        i.renaming_mechanism = renaming_mechanism
        i.custom_driver = driver
      end
    end

    let(:hardware) do
      instance_double(
        Y2Network::Hwinfo, name: "Ethernet Card 0", busid: "00:1c.0", mac: "01:23:45:67:89:ab",
        dev_port: "1", modalias: "virtio:d00000001v00001AF4"
      )
    end
    let(:renaming_mechanism) { :none }
    let(:driver) { nil }
    let(:naming_rules) { [] }
    let(:scr_root) { Dir.mktmpdir }

    before do
      allow(Yast::Execute).to receive(:on_target)
      allow(writer).to receive(:sleep)

      # prevent collision with real hardware
      allow(Y2Network::UdevRule).to receive(:naming_rules).and_return(naming_rules)
      allow(Y2Network::UdevRule).to receive(:drivers_rules).and_return([])
    end

    around do |example|

      FileUtils.cp_r(File.join(DATA_PATH, "scr_read", "etc"), scr_root)
      change_scr_root(scr_root, &example)
    ensure
      FileUtils.remove_entry(scr_root)

    end

    context "when the interface is renamed" do
      before do
        eth0.rename("eth1", renaming_mechanism)
      end

      context "and the reload is forced" do
        let(:reload) { true }

        it "sets the interface down" do
          expect(Yast::Execute).to receive(:on_target).with("/sbin/ifdown", "eth0")
          subject.write(interfaces)
        end
      end

      context "and the reload is not forced (ie: end of the autoinstallation)" do
        context "if not forced the reload" do
          it "does not set the interface down" do
            expect(Yast::Execute).to_not receive(:on_target).with("/sbin/ifdown", any_args)
            subject.write(interfaces)
          end
        end
      end

      context "when the interface is renamed using the MAC" do
        let(:renaming_mechanism) { :mac }

        it "writes a MAC based udev renaming rule" do
          expect(Y2Network::UdevRule).to receive(:write_net_rules) do |rules|
            expect(rules.first.to_s).to eq(
              "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", " \
                "ATTR{type}==\"1\", ATTR{dev_id}==\"0x0\", " \
                "ATTR{address}==\"01:23:45:67:89:ab\", NAME=\"eth1\""
            )
          end
          subject.write(interfaces)
        end

        context "and the interface already has an udev rule" do
          let(:eth0_udev_rule) do
            rule = Y2Network::UdevRule.new_bus_id_based_rename("eth0", "00:1c.0", "1")
            rule.replace_part("DRIVERS", "==", "e1000e")
            rule
          end

          it "touches only the udev keys affected by the change" do
            eth0.udev_rule = eth0_udev_rule
            expect(Y2Network::UdevRule).to receive(:write_net_rules) do |rules|
              expect(rules.first.to_s).to eq(
                "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"e1000e\", " \
                  "ATTR{type}==\"1\", ATTR{address}==\"01:23:45:67:89:ab\", " \
                  "NAME=\"eth1\""
              )
            end
            subject.write(interfaces)
          end
        end
      end

      context "when the interface is renamed using the BUS ID" do
        let(:renaming_mechanism) { :bus_id }

        it "writes a BUS ID based udev renaming rule" do
          expect(Y2Network::UdevRule).to receive(:write_net_rules) do |rules|
            expect(rules.first.to_s).to eq(
              "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", " \
                "ATTR{type}==\"1\", KERNELS==\"00:1c.0\", ATTR{dev_port}==\"1\", " \
                "NAME=\"eth1\""
            )
          end
          subject.write(interfaces)
        end

        context "and the interface already has an udev rule" do
          let(:eth0_udev_rule) do
            rule = Y2Network::UdevRule.new_mac_based_rename("eth0", "00:11:22:33:44:55:66")
            rule.replace_part("DRIVERS", "==", "e1000e")
            rule
          end

          it "touches only the udev keys affected by the change" do
            eth0.udev_rule = eth0_udev_rule
            expect(Y2Network::UdevRule).to receive(:write_net_rules) do |rules|
              expect(rules.first.to_s).to eq(
                "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"e1000e\", " \
                  "ATTR{type}==\"1\", ATTR{dev_id}==\"0x0\", KERNELS==\"00:1c.0\", " \
                  "ATTR{dev_port}==\"1\", NAME=\"eth1\""
              )
            end

            subject.write(interfaces)
          end
        end

      end

      context "when there is some rule for an unknown interface" do
        let(:unknown_rule) do
          Y2Network::UdevRule.new_mac_based_rename("unknown", "00:11:22:33:44:55:66")
        end
        let(:naming_rules) { [unknown_rule] }

        it "keeps the rule" do
          expect(Y2Network::UdevRule).to receive(:write_net_rules) do |rules|
            expect(rules.first.to_s).to eq(unknown_rule.to_s)
          end
          subject.write(interfaces)
        end
      end
    end

    context "when the interface is not renamed" do
      let(:renaming_mechanism) { nil }

      it "does not write a udev rule" do
        expect(Y2Network::UdevRule).to receive(:write_net_rules) do |rules|
          expect(rules).to be_empty
        end
        subject.write(interfaces)
      end
    end

    context "when a driver is set for an interface" do
      let(:driver) { "virtio_net" }

      it "writes an udev driver rule" do
        expect(Y2Network::UdevRule).to receive(:write_drivers_rules) do |rules|
          expect(rules.first.to_s).to eq(
            "ENV{MODALIAS}==\"#{hardware.modalias}\", ENV{MODALIAS}=\"#{driver}\""
          )
        end
        subject.write(interfaces)
      end
    end

    context "after the udev rules have been written" do
      context "when the reload is forced" do
        let(:reload) { true }

        it "refreshes udev" do
          expect(Yast::Execute).to receive(:on_target).with("/usr/bin/udevadm", "control", any_args)
          expect(Yast::Execute).to receive(:on_target).with("/usr/bin/udevadm", "trigger", any_args)
          expect(Yast::Execute).to receive(:on_target).with("/usr/bin/udevadm", "settle")
          subject.write(interfaces)
        end
      end

      context "when the reload is not forced" do
        it "does not refresh udev" do
          expect(Yast::Execute)
            .to_not receive(:on_target).with("/usr/bin/udevadm", "control", any_args)
          expect(Yast::Execute)
            .to_not receive(:on_target).with("/usr/bin/udevadm", "trigger", any_args)
          expect(Yast::Execute)
            .to_not receive(:on_target).with("/usr/bin/udevadm", "settle")
          subject.write(interfaces)
        end
      end

    end
  end
end
