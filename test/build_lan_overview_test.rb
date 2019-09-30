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

include Yast::I18n

describe "LanItemsClass#ip_overview" do
  # smoke test for bnc#1013684
  it "do not crash when devmap for staticaly configured device do not contain PREFIXLEN" do
    devmap = {
      "IPADDR"    => "1.1.1.1",
      "NETMASK"   => "255.255.0.0",
      "BOOTPROTO" => "static",
      "STARTMODE" => "auto"
    }

    expect { Yast::LanItems.ip_overview(devmap) }.not_to raise_error
  end
end
