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
  let(:builder) { instance_double(Y2Network::InterfaceConfigBuilder, type: "eth") }
  subject { described_class.new(builder) }

  include_examples "CWM::ComboBox"

  describe "#validate" do
    let(:valid_name) { "eth0" }
    let(:long_name) { "verylongcustomnicname123" }

    it "passes for valid names only" do
      allow(subject).to receive(:value).and_return valid_name

      expect(Yast::NetworkInterfaces).to receive(:List).and_return([])
      expect(subject.validate).to be true
    end

    # bnc#991486
    it "fails for long names" do
      allow(subject).to receive(:value).and_return long_name

      expect(Yast::NetworkInterfaces).to receive(:List).and_return([])
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
end
