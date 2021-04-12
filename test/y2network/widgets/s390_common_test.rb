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

describe Y2Network::Widgets::S390Layer2 do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  let(:layer2_support) { true }
  let(:layer2_address) { "00:00:00:00:00:00" }
  let(:layer2_support_widget) do
    instance_double("Y2Network::WidgetsS390Layer2Support",
      value: layer2_support, widget_id: "layer2_support")
  end

  let(:layer2_address_widget) do
    instance_double("Y2Network::WidgetsS390Layer2Address",
      value: layer2_address, widget_id: "layer2_address")
  end

  subject { described_class.new(builder) }

  before do
    allow(subject).to receive(:support_widget).and_return(layer2_support_widget)
    allow(subject).to receive(:mac_address_widget).and_return(layer2_address_widget)
  end

  include_examples "CWM::CustomWidget"

  describe "#handle" do
    context "when the event handled is for the layer2_support widget" do
      it "refresh the mac address widget" do
        expect(subject).to receive(:refresh)
        subject.handle("ID" => "layer2_support")
      end
    end

    it "returns nil" do
      allow(subject).to receive(:refresh)
      expect(subject.handle("ID" => "layer2_address")).to be_nil
      expect(subject.handle("ID" => "layer2_support")).to be_nil
    end
  end

  describe "#validate" do
    context "when the layer2 support is not enabled" do
      let(:layer2_support) { false }
      it "returns true" do
        expect(subject.validate).to eql(true)
      end
    end

    context "when the layer2 support is enabled" do
      context "and the MAC address is empty" do
        let(:layer2_address) { "" }

        it "returns true" do
          expect(subject.validate).to eql(true)
        end
      end

      context "and the MAC address is '00:00:00:00:00:00'" do
        it "returns true" do
          expect(subject.validate).to eql(true)
        end
      end

      context "and the MAC provided is a valid one" do
        let(:layer2_address) { "02:00:00:00:01:FD" }

        it "requests user confirmation before storing the defined MAC" do
          expect(subject).to receive(:use_selected_mac?)
          subject.validate
        end

        it "returns true if the user accepts" do
          allow(subject).to receive(:use_selected_mac?).and_return(true)
          expect(subject.validate).to eql(true)
        end

        it "returns false if the user reject" do
          allow(subject).to receive(:use_selected_mac?).and_return(false)
          expect(subject.validate).to eql(false)
        end
      end

      context "and the MAC address provided is invalid" do
        let(:layer2_address) { "02:00:00:00:01" }

        it "returns false" do
          allow(Yast::Popup).to receive(:Error)
          expect(subject.validate).to eql(false)
        end

        it "reports an error" do
          expect(Yast::Popup).to receive(:Error).with(/MAC address provided is not valid/)
          expect(subject.validate).to eql(false)
        end
      end
    end
  end

  describe "#store" do
    context "when the layer2 support checkbox is checked" do
      it "sets the builder layer2 attribute to true" do
        expect(builder).to receive("layer2=").with(true)
        subject.store
      end

      context "and the MAC address is not empty and neither is it '00:00:00:00:00:00'" do
        let(:layer2_address) { "02:00:00:00:01" }

        it "sets the builder lladdress attribute to the MAC address widget value" do
          expect(builder).to receive("lladdress=").with("02:00:00:00:01")
          subject.store
        end
      end

      context "and the MAC address is empty or '00:00:00:00:00:00'" do
        it "sets the builder lladdress attribute to nil" do
          expect(builder).to receive("lladdress=").with(nil)
          subject.store
        end
      end
    end

    context "when the layer2 support checkbox is not checked" do
      let(:layer2_support) { false }

      it "sets the builder layer2 attribute to false" do
        expect(builder).to receive("layer2=").with(false)
        subject.store
      end

      it "sets the builder lladdress attribute to nil" do
        expect(builder).to receive("lladdress=").with(nil)
        subject.store
      end
    end
  end
end

describe Y2Network::Widgets::S390Layer2Support do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  subject { described_class.new(builder) }

  include_examples "CWM::CheckBox"
end

describe Y2Network::Widgets::S390Layer2Address do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"
end
