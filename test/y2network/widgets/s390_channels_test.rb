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
require "y2network/widgets/s390_channels"
require "y2network/interface_config_builder"

require "cwm/rspec"

describe Y2Network::Widgets::S390ReadChannel do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  let(:read_channel) { "0.0.0700" }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"

  describe "#init" do
    it "initializes the widget value with the device read channel" do
      builder.read_channel = read_channel
      expect(subject).to receive(:value=).with(read_channel)
      subject.init
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return("0.0.0800")
    end

    it "modifies the device read channel with the widget value" do
      builder.read_channel = read_channel
      expect { subject.store }.to change { builder.read_channel }.from(read_channel).to("0.0.0800")
    end
  end
end

describe Y2Network::Widgets::S390WriteChannel do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  let(:write_channel) { "0.0.0701" }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"

  describe "#init" do
    it "initializes the widget value with the device write channel" do
      builder.write_channel = write_channel
      expect(subject).to receive(:value=).with(write_channel)
      subject.init
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return("0.0.0801")
    end

    it "modifies the device write channel with the widget value" do
      builder.write_channel = write_channel
      expect { subject.store }.to change { builder.write_channel }.from(write_channel).to("0.0.0801")
    end
  end
end

describe Y2Network::Widgets::S390DataChannel do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  let(:data_channel) { "0.0.0702" }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"

  describe "#init" do
    it "initializes the widget value with the device data channel" do
      builder.data_channel = data_channel
      expect(subject).to receive(:value=).with(data_channel)
      subject.init
    end
  end

  describe "#store" do
    before do
      allow(subject).to receive(:value).and_return("0.0.0802")
    end

    it "modifies the device data channel with the widget value" do
      builder.data_channel = data_channel
      expect { subject.store }.to change { builder.data_channel }.from(data_channel).to("0.0.0802")
    end
  end
end

describe Y2Network::Widgets::S390Channels do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  subject { described_class.new(builder) }
  include_examples "CWM::CustomWidget"
end
