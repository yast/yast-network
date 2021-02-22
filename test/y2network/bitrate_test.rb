# Copyright (c) [2021] SUSE LLC
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

require_relative "../test_helper"
require "y2network/bitrate"

describe Y2Network::Bitrate do
  describe ".parse" do
    context "when the string contains a 'kb/s'" do
      it "returns an object representing the same value" do
        bitrate = described_class.parse("54 kb/s")
        expect(bitrate.to_i).to eq(54_000)
      end
    end

    context "when the string contains a 'Mb/s'" do
      it "returns an object representing the same value" do
        bitrate = described_class.parse("54 Mb/s")
        expect(bitrate.to_i).to eq(54_000_000)
      end
    end

    context "when the string contains a 'Gb/s'" do
      it "returns an object representing the same value" do
        bitrate = described_class.parse("1 Gb/s")
        expect(bitrate.to_i).to eq(1_000_000_000)
      end
    end

    context "when the unit is missing from the string" do
      it "returns an object representing the same value" do
        bitrate = described_class.parse("64")
        expect(bitrate.to_i).to eq(64)
      end
    end

    context "when the string cannot be parsed" do
      it "raises a ParseError exception" do
        expect { described_class.parse("something") }
          .to raise_error(Y2Network::Bitrate::ParseError)
      end
    end
  end

  describe "#to_s" do
    context "Gb/s" do
      it "returns" do
        bitrate = described_class.new(54000000000)
        expect(bitrate.to_s).to eq("54 Gb/s")
      end
    end

    context "Mb/s" do
      it "returns" do
        bitrate = described_class.new(54000000)
        expect(bitrate.to_s).to eq("54 Mb/s")
      end
    end

    context "kb/s" do
      it "returns" do
        bitrate = described_class.new(54500)
        expect(bitrate.to_s).to eq("54.5 kb/s")
      end
    end

    context "bits" do
      it "returns" do
        bitrate = described_class.new(128)
        expect(bitrate.to_s).to eq("128 b/s")
      end
    end
  end
end
