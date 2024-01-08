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

require_relative "test_helper"

require "yast"

# creating a wrapper for Yast's 'header' file
$LOAD_PATH.unshift File.expand_path("../src", __dir__)
require "include/network/lan/s390"

class NetworkLanS390IncludeTestClient < Yast::Client
  include Singleton

  def initialize
    super
    Yast.include self, "network/lan/s390.rb"
  end
end

Yast.import "Arch"
Yast.import "FileUtils"

describe "NetworkLanS390Include::s390_DriverLoaded" do
  subject { NetworkLanS390IncludeTestClient.instance }
  DEVNAME = "devname".freeze

  before(:each) do
    allow(Yast::Arch)
      .to receive(:s390)
      .and_return(true)
  end

  # it checks if a driver which emulates common linux device
  # on top of s390 one is loaded already
  it "succeeds when driver is already loaded" do
    expect(Yast::FileUtils)
      .to receive(:IsDirectory)
      .with("#{Yast::NetworkLanS390Include::SYS_DIR}/#{DEVNAME}")
      .and_return(true)

    expect(subject.s390_DriverLoaded(DEVNAME)).to be true
  end

  it "fails when driver is not loaded" do
    expect(Yast::FileUtils)
      .to receive(:IsDirectory)
      .with("#{Yast::NetworkLanS390Include::SYS_DIR}/#{DEVNAME}")
      .and_return(false)

    expect(subject.s390_DriverLoaded(DEVNAME)).to be false
  end
end
