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

require "y2network/route"
require "y2network/widgets/destination"

describe Y2Network::Widgets::Destination do
  let(:widget_value) { "-" }
  let(:route) { Y2Network::Route.new }
  subject { described_class.new(route) }

  before do
    allow(subject).to receive(:value).and_return(widget_value)
    allow(Yast::UI).to receive(:ChangeWidget)
  end

  include_examples "CWM::InputField"

  describe "#validate" do
    context "when invalid ip is used" do
      let(:widget_value) { "666.0.0.1" }

      it "returns false" do
        expect(subject.validate).to eq false
      end

      it "focus widget" do
        expect(subject).to receive(:focus)

        subject.validate
      end

      it "shows popup" do
        expect(Yast::Popup).to receive(:Error)

        subject.validate
      end
    end
  end

  describe "#init" do
    it "sets valid characters for widget" do
      expect(Yast::UI).to receive(:ChangeWidget).with(anything, :ValidChars, anything)

      subject.init
    end

    context "route.to is :default" do
      let(:route) { Y2Network::Route.new(to: :default) }

      it "sets values to '-'" do
        expect(subject).to receive(:value=).with("-")

        subject.init
      end
    end

    context "route.to is IPAddr" do
      let(:route) { Y2Network::Route.new(to: IPAddr.new("127.0.0.1/24")) }
      it "sets value including prefix" do
        expect(subject).to receive(:value=).with("127.0.0.0/24")

        subject.init
      end
    end
  end

  describe "#store" do
    context "value is '-'" do
      let(:widget_value) { "-" }

      it "stores :default to route" do
        subject.store

        expect(route.to).to eq :default
      end
    end

    context "value is ip address" do
      let(:widget_value) { "127.0.0.1/24" }

      it "stores IPAddr to route" do
        subject.store

        expect(route.to).to eq IPAddr.new("127.0.0.0/24")
      end
    end

  end
end
