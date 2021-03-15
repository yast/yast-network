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

require_relative "../../test_helper"

require "yast"
require "y2network/interface_config_builders/ctc"
require "y2network/interface_type"

describe Y2Network::InterfaceConfigBuilders::Ctc do
  subject(:builder) do
    res = Y2Network::InterfaceConfigBuilders::Ctc.new
    res.name = "ctc0"
    res
  end

  describe "#type" do
    it "returns ctc type" do
      expect(subject.type).to eq Y2Network::InterfaceType::CTC
    end
  end

  describe "#save" do
    let(:network_config) { { "WAIT_FOR_INTERFACES" => wfi } }
    let(:yast_config) { Y2Network::Config.new(source: :wicked) }

    around do |test|
      orig_config = Yast::NetworkConfig.Config
      Yast::NetworkConfig.Config = network_config

      test.call

      Yast::NetworkConfig.Config = orig_config
    end

    before(:each) do
      allow(Yast::Lan).to receive(:yast_config).and_return(yast_config)
    end

    # 40 is magic number found in the code
    context "When WAIT_FOR_INTERFACES is < 40" do
      let(:wfi) { 10 }

      it "sets minimal WAIT_FOR_INTERFACES to a reasonable default" do
        expect { subject.save }
          .to change { Yast::NetworkConfig.Config["WAIT_FOR_INTERFACES"] }
          .from(wfi)
          .to(40)
      end
    end

    context "When WAIT_FOR_INTERFACES is >= 40" do
      let(:wfi) { 50 }

      it "sets keeps WAIT_FOR_INTERFACES it is" do
        subject.save
        expect(Yast::NetworkConfig.Config["WAIT_FOR_INTERFACES"])
          .to eql wfi
      end
    end
  end
end
