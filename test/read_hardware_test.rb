#! /usr/bin/env rspec

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

require_relative "test_helper"

require "yast"

require_relative "netcard_probe_helper"

class ReadHardwareTestClass
  def initialize
    Yast.include self, "network/routines.rb"
  end
end

describe "#ReadHardware" do
  subject { ReadHardwareTestClass.new }

  def storage_only_devices
    devices = probe_netcard.select { |n| n["storageonly"] }
    devices.map { |d| d["dev_name"] }
  end

  # testsuite for bnc#841170
  it "excludes storage only devices" do
    allow(Yast::SCR).to receive(:Read).and_return(nil)
    allow(Yast::SCR).to receive(:Read).with(path(".probe.netcard")) { probe_netcard }

    read_storage_devices = subject.ReadHardware("netcard").select do |d|
      storage_only_devices.include? d["dev_name"]
    end

    expect(read_storage_devices).to be_empty
  end
end
