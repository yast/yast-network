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

require "y2network/widgets/interface_name"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::InterfaceName do
  let(:builder) do
    Y2Network::InterfaceConfigBuilder.for("eth").tap { |b| b.name = "eth0" }
  end
  subject { described_class.new(builder) }

  include_examples "CWM::ComboBox"

  describe "#validate" do
    let(:valid_name) { "eth0" }
    let(:long_name) { "verylongcustomnicname123" }

    it "passes for valid names only" do
      allow(subject).to receive(:value).and_return valid_name
      allow(Yast::NetworkInterfaces).to receive(:List).and_return []
      expect(Yast::Popup).to_not receive(:Error)

      expect(subject.validate).to be true
    end

    # bnc#991486
    it "fails for long names" do
      allow(subject).to receive(:value).and_return long_name
      allow(Yast::NetworkInterfaces).to receive(:List).and_return []

      expect(Yast::UI).to receive(:SetFocus)
      expect(subject.validate).to be false
    end

    it "fails for already used names" do
      allow(subject).to receive(:value).and_return valid_name
      allow(Yast::NetworkInterfaces).to receive(:List).and_return [valid_name]

      expect(Yast::UI).to receive(:SetFocus)
      expect(subject.validate).to be false
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return(value)
    end

    context "when the name has changed" do
      let(:value) { "eth1" }

      it "renames the interface" do
        expect(builder).to receive(:rename_interface).with(value)
        subject.store
      end
    end

    context "when the name has changed" do
      let(:value) { builder.name }

      it "does not rename the interface" do
        expect(builder).to_not receive(:rename_interface)
        subject.store
      end
    end
  end
end
