#!/usr/bin/env rspec

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require_relative "../../test_helper.rb"
require "y2remote/remote"

describe Y2Remote::Remote do
  subject { described_class.instance }

  describe ".disabled?" do
    it "" do

    end
  end

  describe ".enabled?" do
    it "returns true if some vnc service is running" do
      allow(subject).to receive(:modes).and_return([:vnc])

      expect(subject)
    end
  end

  describe ".read" do
    it "returns true" do
      expect(subject.read).to eq(true)
    end

    it "checks in which mode it is running" do

      subject.read
    end
  end

  describe ".proposed?" do
    let(:proposed) { false }
    context "when the remote config has been already proposed" do
      let(:proposed) { true }

      it "returns true" do
        expect(subject).to receive(:proposed).and_return(proposed)
        expecT(subject.proposed?).to eql(proposed)
      end
    end

    context "when the remote config has not been proposed yet" do
      it "returns false" do
        expect(subject).to receive(:proposed).and_return(proposed)
        expecT(subject.proposed?).to eql(proposed)
      end
    end
  end
end
