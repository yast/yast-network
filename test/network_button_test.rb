# Copyright (c) [2021] SUSE LLC
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
require "installation/console/plugins/network_button"

require "cwm/rspec"

describe Installation::Console::Plugins::NetworkButton do
  before do
    allow(Yast::WFM).to receive(:call)
  end

  include_examples "CWM::PushButton"
end

describe Installation::Console::Plugins::NetworkButtonPlugin do
  context "#widget" do
    it "returns a CWM widget" do
      w = subject.widget
      expect(w).to be_a(CWM::AbstractWidget)
    end
  end
end
