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
require "y2network/widgets/ip_address"

require "cwm/rspec"

describe Y2Network::Widgets::IPAddress do
  let(:ip_settings) { OpenStruct.new(ip_address: "192.168.122.20") }
  subject { described_class.new(ip_settings) }

  include_examples "CWM::InputField"

  describe "#init" do
    it "sets the input value with the IP settings address" do
      expect(subject).to receive(:value=).with("192.168.122.20")

      subject.init
    end

    context "when it is initialized with the focus option as true" do
      subject { described_class.new(ip_settings, focus: true) }

      it "gets the focus" do
        expect(subject).to receive(:focus)

        subject.init
      end
    end
  end
end
