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

require "y2network/widgets/interfaces_table"

Yast.import "Lan"

describe Y2Network::Widgets::InterfacesTable do
  subject { described_class.new(double(:"value=" => nil)) }

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(double(interfaces: [], connections: []))
    allow(Yast::UI).to receive(:QueryWidget).and_return([])
    allow(subject).to receive(:create_description).and_return("")
  end

  include_examples "CWM::Table"
end
