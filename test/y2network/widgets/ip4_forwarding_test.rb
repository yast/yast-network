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
require "cwm/rspec"

require "y2network/widgets/ip4_forwarding"
require "y2network/config"
require "y2network/routing"
require "y2network/interface"

describe Y2Network::Widgets::IP4Forwarding do
  subject { described_class.new(config) }
  let(:config) do
    Y2Network::Config.new(
      source:     :sysconfig,
      interfaces: [Y2Network::Interface.new("eth0")],
      routing:    Y2Network::Routing.new(tables: [])
    )
  end

  include_examples "CWM::CheckBox"
end
