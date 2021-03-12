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

require "y2network/widgets/vlan_id"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::VlanID do
  let(:builder) do
    Y2Network::InterfaceConfigBuilder.for("vlan").tap do |vlan|
      vlan.name = "vlan0"
    end
  end

  subject { described_class.new(builder) }

  include_examples "CWM::IntField"

  describe "#store" do
    let(:value) { 0 }

    before do
      allow(subject).to receive(:value).and_return(value)
    end

    context "when the value is modified since read" do
      let(:value) { 20 }

      it "suggest the user to modify also the interface name" do
        expect(Yast::Popup).to receive(:YesNo).with(/from 'vlan0' to 'vlan20'/)

        subject.store
      end

      context "and the user accepts the suggestion" do
        before do
          allow(Yast::Popup).to receive(:YesNo).and_return(true)
        end

        it "renames the vlan interface name" do
          expect(builder).to receive(:rename_interface).with("vlan20")

          subject.store
        end
      end
    end

    context "when the value is not modified since read" do
      it "does nothing" do
        expect(Yast::Popup).to_not receive(:YesNo)
        expect(builder).to_not receive(:vlan_id=)

        subject.store
      end
    end
  end
end
