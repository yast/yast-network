#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require_relative "test_helper"

Yast.import "NetHwDetection"

describe "NetHwDetection" do
  subject { Yast::NetHwDetection }
  let(:hwinfo) { [] }

  before do
    allow(subject).to receive(:ReadHardware).with("netcard").and_return(hwinfo)
  end

  describe "#LoadNetModules" do
    it "reads the hwinfo of the network cards present in the system" do
      expect(subject).to receive(:ReadHardware).with("netcard")
      subject.LoadNetModules
    end

    context "when the system does not have network cards" do
      it "returns false" do
        expect(subject.LoadNetModules).to eq(false)
      end
    end

    context "when there is some network card which driver is not active" do
      let(:loaded) { true }

      before do
        allow(subject).to receive(:already_loaded?).with("qeth").and_return(loaded)
      end

      let(:hwinfo) do
        [
          {
            "active" => false, "bus" => "none", "busid" => "", "dev_name" => "", "driver" => "",
            "drivers" => [{ "active" => false, "modprobe" => true, "modules" => [["qeth", ""]] }],
            "link" => nil, "mac" => "", "modalias" => "", "module" => "qeth",
            "name" => "OSA Express Network card", "num" => 0, "options" => "",
            "permanent_mac" => "", "requires" => [], "sysfs_id" => "", "type" => "qeth",
            "udi" => "", "unique" => "rdCR.n_7QNeEnh23", "wl_auth_modes" => nil,
            "wl_bitrates" => nil, "wl_channels" => nil, "wl_enc_modes" => nil
          },
          {
            "active" => true, "bus" => "Virtio", "busid" => "virtio0", "dev_name" => "eth0",
            "drivers" => [
              { "active" => true, "modprobe" => true, "modules" => [["virtio_net", ""]] }
            ], "driver" => "virtio_net", "link" => false, "mac" => "52:54:00:12:34:56",
            "modalias" => "virtio:d00000001v00001AF4", "module" => "virtio_net",
            "name" => "Ethernet Card 0", "num" => 1, "options" => "",
            "parent_busid" => "0000:00:02.0", "permanent_mac" => "52:54:00:12:34:56",
            "requires" => [], "sysfs_id" => "/devices/pci0000:00/0000:00 =>02.0/virtio0",
            "type" => "eth", "udi" => "", "unique" => "Prmq.VIRhsc57kTD", "wl_auth_modes" => nil,
            "wl_bitrates" => nil, "wl_channels" => nil, "wl_enc_modes" => nil
          }
        ]
      end

      context "and the driver module is not loaded" do
        let(:loaded) { false }

        it "modprobes the inactive driver" do
          expect(subject).to receive(:load_module).with("qeth")
          subject.LoadNetModules
        end
      end

      context "and the driver was already loaded" do
        it "does not try to modprobe the module" do
          expect(subject).to_not receive(:load_module)
          subject.LoadNetModules
        end
      end
    end
  end
end
