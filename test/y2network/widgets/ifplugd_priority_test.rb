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

require "y2network/widgets/ifplugd_priority"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::IfplugdPriority do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilder.for("eth")
    res.ifplugd_priority = 50
    res
  end
  subject { described_class.new(builder) }

  include_examples "CWM::IntField"

  describe "#minimum" do
    it "returns 0" do
      expect(subject.minimum).to eq 0
    end
  end

  describe "#maximum" do
    it "returns 100" do
      expect(subject.maximum).to eq 100
    end
  end

  describe "#init" do
    it "sets widget value to IFPLUGD_PRIORITY as integer" do
      expect(subject).to receive(:value=).with(50)

      subject.init
    end
  end

  describe "#store" do
    it "sets IFPLUGD_PRIORITY according to widget value as string" do
      expect(subject).to receive(:value).and_return(20)

      subject.store

      expect(builder.ifplugd_priority).to eq 20
    end
  end
end
