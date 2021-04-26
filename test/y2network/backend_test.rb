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

require_relative "../test_helper"
require "y2network/backend"

describe Y2Network::Backend do
  let(:supported_backends) { [:netconfig, :network_manager, :none, :wicked] }
  let(:installed_backends) { [:netconfig, :none, :wicked] }
  let(:network_manager) { described_class.by_id(:network_manager) }

  describe "#all" do
    it "returns all the supported backends" do
      expect(described_class.all.map(&:id).sort).to eql(supported_backends)
    end
  end

  describe "#available" do
    before do
      described_class.all.each do |backend|
        allow(backend).to receive(:available?).and_return(true)
      end
    end

    it "returns all the supported and installed backends" do
      expect(network_manager).to receive(:available?).and_return(false)
      expect(described_class.available.map(&:id).sort).to eql(installed_backends)
    end
  end

  describe "#by_id" do
    it "returns the backend with the given id when present" do
      expect(described_class.by_id(:wicked).class).to eql(Y2Network::Backends::Wicked)
      expect(described_class.by_id(:wicked).id).to eql(:wicked)
    end

    it "returns nil when the backend is not supported" do
      expect(described_class.by_id(:networkd)).to be_nil
    end
  end

  describe ".label" do
    it "raises an exception when not implemented" do
      expect { described_class.new(:networkd).label }.to raise_error(NotImplementedError)
    end

    it "returns the translated backend label when implemented" do
      expect(network_manager.label).to eq("Network Manager")
    end
  end

  describe ".id" do
    it "returns the backend id" do
      expect(network_manager.id).to eql(:network_manager)
    end
  end
end
