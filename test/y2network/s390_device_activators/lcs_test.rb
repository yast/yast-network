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

require "y2network/s390_device_activators/lcs"
require "y2network/interface_config_builders/lcs"

describe Y2Network::S390DeviceActivators::Lcs do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilders::Lcs.new
    res.name = "lcs0"
    res
  end

  subject(:activator) { Y2Network::S390DeviceActivator.for(builder) }

  let(:executor) { double("Yast::Execute", on_target!: "") }
  let(:initialize_channels) { true }
  let(:chzdev_output) { ["", "", 0] }
  before do
    allow(Yast::Execute).to receive(:stdout).and_return(executor)
    builder.read_channel = "0.0.0900" if initialize_channels
    builder.write_channel = "0.0.0901" if initialize_channels
    builder.timeout = 15
  end

  describe "#configure" do
    it "tries to activate the group device associated with the defined device id" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/sbin/chzdev", "lcs", subject.device_id, "-e", "lancmd_timeout=15",
          stdout: :capture, stderr: :capture, allowed_exitstatus: 0..255)
      subject.configure
    end

    it "returns an array with the stdout, stderr, and command status" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/sbin/chzdev", "lcs", subject.device_id, "-e", "lancmd_timeout=15",
          stdout: :capture, stderr: :capture, allowed_exitstatus: 0..255)
        .and_return(chzdev_output)

      expect(subject.configure).to eq(chzdev_output)
    end
  end
end
