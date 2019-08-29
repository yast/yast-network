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

require "y2network/dialogs/add_interface"
require "y2network/interface_config_builder"

describe Y2Network::Dialogs::AddInterface do
  include_examples "CWM::Dialog"

  describe "#run" do
    before do
      allow(Y2Network::Widgets::InterfaceType).to receive(:new).and_return(double(result: "eth"))
      allow(subject).to receive(:cwm_show).and_return(:abort)
    end

    it "returns nil if canceled" do
      allow(subject).to receive(:cwm_show).and_return(:abort)

      expect(subject.run).to eq nil
    end

    it "returns interface config builder if approved" do
      allow(subject).to receive(:cwm_show).and_return(:next)

      expect(subject.run).to be_a Y2Network::InterfaceConfigBuilder
    end
  end
end
