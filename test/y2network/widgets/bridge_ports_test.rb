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
require "y2network/interface_config_builders/bridge"

describe Y2Network::Widgets::BridgePorts do
  subject { described_class.new(Y2Network::InterfaceConfigBuilders::Bridge.new) }

  include_examples "CWM::MultiSelectionBox"

  describe "#validate" do
    context "when all devices are not yet configured" do
      it "returns true" do

        expect(subject.validate).to eql(true)
      end
    end

    context "when some of the enslaved interfaces are configured" do
      it "warns the user and request confirmation to continue" do
        # yeah, tricky mock, not sure if there is easier way
        allow(Yast::NetworkInterfaces).to receive(:FilterDevices)
          .and_return(double(:[] => { "eth0" => { "BOOTPROTO"  => "dhcp" } }))
        allow(subject).to receive(:value).and_return(["eth0"])

        expect(Yast::Popup).to receive(:ContinueCancel).and_return(true)

        expect(subject.validate).to eql(true)
      end
    end
  end
end
