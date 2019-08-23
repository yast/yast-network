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

Yast.import "LanItems"

class WirelessTestClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/wireless.rb"
  end
end

describe "WirelessInclude" do
  subject { WirelessTestClass.new }

  describe "#InitPeapVersion" do
    before do
      allow(Yast::UI).to receive(:ChangeWidget)
    end

    it "Enables widget if WPA_EAP_MODE is PEAP" do
      Yast::LanItems.wl_wpa_eap["WPA_EAP_MODE"] = "PEAP"
      expect(Yast::UI).to receive(:ChangeWidget).with(Id("test"), :Enabled, true)

      subject.InitPeapVersion("test")
    end
  end
end
