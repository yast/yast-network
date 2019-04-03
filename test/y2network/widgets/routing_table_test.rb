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

require "y2network/route"
require "y2network/widgets/routing_table"
require "y2network/routing_table"

describe Y2Network::Widgets::RoutingTable do
  let(:routing_table) do
    Y2Network::RoutingTable.new([
                                  Y2Network::Route.new(to: IPAddr.new("127.0.0.1/24")),
                                  Y2Network::Route.new(to: :default)
                                ])
  end
  subject { described_class.new(routing_table) }

  include_examples "CWM::Table"
end
