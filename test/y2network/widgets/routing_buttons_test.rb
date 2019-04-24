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

require "y2network/widgets/routing_buttons"
require "y2network/dialogs/route"

describe Y2Network::Widgets::AddRoute do
  before do
    allow(Y2Network::Dialogs::Route).to receive(:run).and_return(:ok)
  end

  let(:routing_table) { double.as_null_object }
  let(:config) { double(interfaces: [Y2Network::Interface.new("eth0")]) }
  subject { described_class.new(routing_table, config) }

  include_examples "CWM::PushButton"
end

describe Y2Network::Widgets::EditRoute do
  before do
    allow(Y2Network::Dialogs::Route).to receive(:run).and_return(:ok)
  end

  let(:routing_table) { double.as_null_object }
  let(:config) { double(interfaces: [Y2Network::Interface.new("eth0")]) }
  subject { described_class.new(routing_table, config) }

  include_examples "CWM::PushButton"
end

describe Y2Network::Widgets::DeleteRoute do
  let(:routing_table) { double.as_null_object }
  subject { described_class.new(routing_table) }

  include_examples "CWM::PushButton"
end
