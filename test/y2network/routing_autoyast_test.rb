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

require_relative "../test_helper"

describe Y2Network::RoutingAutoyast do
  let(:forwarding_profile) { "ip_forward" => true }
  let(:routes_profile) do
    {
      "routes" => [
        {
          "destination" => "default",
          "gateway"     => "192.168.1.1",
          "netmask"     => "255.255.255.0",
          "device"      => "-"
        },
        {

        }
      ]
    }
  end

  describe "#import" do
  end

  describe "#export" do

  end
end
