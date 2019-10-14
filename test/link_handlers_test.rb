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

# need a class to stub the sleep call; hard to stub it on Kernel
class LinkHandlersClass
  def initialize
    Yast.include self, "network/routines.rb"
  end
end

describe "phy_connected?" do
  subject { LinkHandlersClass.new }

  before(:each) do
    allow(Yast::SCR).to receive(:Execute).with(path(".target.bash"), //) { 0 }
    allow(subject).to receive(:sleep)
  end

  it "returns true if PHY layer is available" do
    allow(subject).to receive(:carrier?).and_return true
    expect(subject.phy_connected?("enp0s3")).to eql true
  end

  it "returns false if PHY layer is not available" do
    allow(subject).to receive(:carrier?).and_return false
    expect(subject.phy_connected?("enp0s3")).to eql false
  end
end
