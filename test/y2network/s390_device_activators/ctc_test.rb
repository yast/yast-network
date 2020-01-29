#!/usr/bin/env rspec

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

require "y2network/s390_device_activators/ctc"
require "y2network/interface_config_builders/ctc"

describe Y2Network::S390DeviceActivators::Ctc do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilders::Ctc.new
    res.name = "ctc0"
    res
  end

  subject(:activator) { Y2Network::S390DeviceActivators::Ctc.new(builder) }

  let(:executor) { double("Yast::Execute", on_target!: "") }
  let(:initialize_channels) { true }
  before do
    allow(Yast::Execute).to receive(:stdout).and_return(executor)
    builder.read_channel = "0.0.0900" if initialize_channels
    builder.write_channel = "0.0.0901" if initialize_channels
    builder.protocol = 0
  end

  describe "#configure" do
    it "tries to activate the group device associated with the defined device id" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/sbin/chzdev", "ctc", subject.device_id, "-e",
          "protocol=#{builder.protocol}", allowed_exitstatus: 0..255)
        .and_return(0)
      subject.configure
    end

    context "when activated succesfully" do
      it "returns true" do
        expect(Yast::Execute).to receive(:on_target!).and_return(0)
        expect(subject.configure).to eq(true)
      end
    end

    context "when failed the activation and returned a non zero return code" do
      it "returns false" do
        expect(Yast::Execute).to receive(:on_target!).and_return(34)
        expect(subject.configure).to eq(false)
      end
    end
  end

  describe "#configured_interface" do
    before do
      allow(executor).to receive(:on_target!)
        .with(["/sbin/lszdev", activator.device_id, "-c", "names", "-n"])
        .and_return("ctc1")
    end

    it "obtains the network interface associated with builder device id" do
      expect(subject.configured_interface).to eq("ctc1")
    end
  end

  describe "#device_id" do
    it "returns the s390 group device id" do
      expect(subject.device_id).to eql("0.0.0900:0.0.0901")
    end
  end

  describe "#propose_channels" do
    context "when the read and write channel have not been initialized" do
      let(:initialize_channels) { false }
      let(:device_id) { "0.0.0800:0.0.0801" }
      let(:write_channel) { "0.0.0801" }
      let(:hwinfo) { Y2Network::Hwinfo.new("busid" => write_channel) }

      before do
        allow(subject).to receive(:device_id_from).with(write_channel).and_return(device_id)
        allow(builder).to receive(:hwinfo).and_return(hwinfo)
      end

      it "initializes them from the given busid" do
        expect { subject.propose_channels }.to change { subject.device_id }.from(nil).to(device_id)
      end
    end
  end

  describe "#propose!" do
    context "when no device id has been initialized" do
      let(:initialize_channels) { false }
      it "proposes the channel device ids to be used" do
        expect(subject).to receive(:propose_channels)
        subject.propose!
      end
    end

    context "when the channel device ids have been set already" do
      it "does not propose anything" do
        expect(subject).to_not receive(:propose_channels)
        subject.propose!
      end
    end
  end

end
