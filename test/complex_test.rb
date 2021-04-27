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

Yast.import "Stage"

class NetworkLanComplexIncludeClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/complex.rb"
  end
end

describe "NetworkLanComplexInclude" do
  subject { NetworkLanComplexIncludeClass.new }

  describe "#input_done?" do
    BOOLEAN_PLACEHOLDER = "placeholder (true or false)".freeze

    let(:wicked_config) { Y2Network::Config.new(source: :wicked) }
    let(:nm_config) { Y2Network::Config.new(source: :network_manager) }

    context "when not running in installer" do
      before(:each) do
        allow(Yast::Stage)
          .to receive(:initial)
          .and_return(false)
      end

      it "returns true for input different than :abort" do
        expect(subject.input_done?(:no_abort)).to eql true
      end

      it "returns true for input equal to :abort in case of no user modifications" do
        allow(Yast::Lan)
          .to receive(:yast_config)
          .and_return(wicked_config)
        allow(Yast::Lan)
          .to receive(:system_config)
          .and_return(wicked_config)

        expect(subject.input_done?(:abort)).to eql true
      end

      it "asks for confirmation in case of a user modification" do
        allow(Yast::Lan)
          .to receive(:yast_config)
          .and_return(wicked_config)
        allow(Yast::Lan)
          .to receive(:system_config)
          .and_return(nm_config)

        expect(subject).to receive(:ReallyAbort)

        subject.input_done?(:abort)
      end
    end

    context "when running in installer" do
      before(:each) do
        allow(Yast::Stage)
          .to receive(:initial)
          .and_return(true)
      end

      it "asks user for installation abort confirmation for input equal to :abort" do
        expect(Yast::Popup)
          .to receive(:ConfirmAbort)
          .and_return(BOOLEAN_PLACEHOLDER)

        expect(subject.input_done?(:abort)).to eql BOOLEAN_PLACEHOLDER
      end
    end
  end
end
