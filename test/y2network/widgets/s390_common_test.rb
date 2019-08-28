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
require "y2network/widgets/s390_common"
require "y2network/interface_config_builder"

require "cwm/rspec"

describe Y2Network::Widgets::S390LanCmdTimeout do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("lcs") }
  subject { described_class.new(builder) }
  include_examples "CWM::InputField"
end

describe Y2Network::Widgets::S390Protocol do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilder.for("ctc")
    res.name = "ctc0"
    res.protocol = 1
    res
  end

  subject { described_class.new(builder) }

  include_examples "CWM::ComboBox"

  describe "#init" do
    it "initializes the widget value with the configured protocol" do
      expect(subject).to receive(:value=).with("1")
      subject.init
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return("4")
    end

    it "modifies the builder protocol attribute with the widget value" do
      expect { subject.store }.to change { builder.protocol }.from(1).to(4)
    end
  end

end

describe Y2Network::Widgets::S390PortNumber do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  subject { described_class.new(builder) }

  include_examples "CWM::ComboBox"
end

describe Y2Network::Widgets::S390Attributes do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"
end
