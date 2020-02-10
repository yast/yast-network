# Copyright (c) [2020] SUSE LLC
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

require "y2network/presenters/summary"

describe Y2Network::Presenters::Summary do
  let(:config) { double("Y2Network::Config") }
  let(:summary) { double("Y2Network::Presenters::RoutingSummary", text: "routing_summary") }

  describe ".text_for" do
    before do
      allow(described_class).to receive(:for).with(config, "routing").and_return(summary)
    end

    it "returns a summary text for the given config section" do
      expect(described_class.text_for(config, "routing")).to eq("routing_summary")
    end
  end

  describe ".for" do
    context "specialized presenter class for given config section exists" do
      it "returns new instance of that class" do
        expect(described_class.for(config, "dns").class.to_s).to eq(
          "Y2Network::Presenters::DNSSummary"
        )
      end
    end

    context "specialized class for given section does not exist" do
      it "returns nil" do
        expect(described_class.for(config, "wrong_summary")).to eq(nil)
      end
    end
  end
end
