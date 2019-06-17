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

require "y2network/widgets/bridge_ports"
require "y2network/interface_config_builders/br"

describe Y2Network::Widgets::BridgePorts do
  let(:builder) { Y2Network::InterfaceConfigBuilders::Br.new }
  subject { described_class.new(builder) }

  before do
    allow(builder).to receive(:already_configured?).and_return(false)
  end

  include_examples "CWM::MultiSelectionBox"

  describe "#validate" do
    context "when all devices are not yet configured" do
      it "returns true" do

        expect(subject.validate).to eql(true)
      end
    end

    context "when some of the enslaved interfaces are configured" do
      it "warns the user and request confirmation to continue" do
        allow(builder).to receive(:already_configured?).and_return(true)

        expect(Yast::Popup).to receive(:ContinueCancel).and_return(true)

        expect(subject.validate).to eql(true)
      end
    end
  end
end
