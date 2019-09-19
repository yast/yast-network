#!/usr/bin/env rspec

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

require_relative "test_helper"

require "yast"
require_relative "../src/clients/lan_auto"

describe Yast::LanAutoClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return([func])
      allow(Yast::WFM).to receive(:Args).with(0).and_return(func)
    end

    context "when func is GetModified" do
      let(:func) { "GetModified" }

      it "returns true if Lan.GetModified is true" do
        expect(Yast::Lan).to receive(:Modified).and_return(true)
        expect(subject.main).to eq(true)
      end

      it "returns false if Lan.GetModified is false" do
        expect(Yast::Lan).to receive(:Modified).and_return(false)
        expect(subject.main).to eq(false)
      end
    end
  end
end
