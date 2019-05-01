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
require "y2network/config_builder/defaults"

describe Y2Network::ConfigBuilder::Defaults do
  subject(:subject) { described_class.new }

  describe "#config" do
    it "builds a new Y2Network::Routing config with default values" do
      routing_config = subject.config.routing
      expect(routing_config.forward_ipv4).to eq(false)
      expect(routing_config.forward_ipv6).to eq(false)
      expect(routing_config.routes).to be_empty
    end
  end
end
