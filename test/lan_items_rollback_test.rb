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
Yast.import "LanItems"

describe "LanItemsClass" do
  subject { Yast::LanItems }

  let(:mocked_items) do
    {
      1 => {
        "ifcfg" => "eth1"
      },
      2 => {
        "commited" => false,
        "ifcfg"    => "eth2"
      },
      3 => {
        "commited" => false,
        "hwinfo"   => {
          "name"     => "SUSE test card",
          "dev_name" => "eth3"
        },
        "ifcfg"    => "eth3"
      }
    }
  end

  describe "#Rollback" do
    context "when the current item is edited" do
      before do
        Yast::LanItems.operation = :edit
        subject.Items = mocked_items
        subject.current = 1
      end

      it "leaves Items untouched" do
        subject.Rollback
        expect(subject.Items).to eq(mocked_items)
      end
    end

    context "when the current item is added (configured without hwinfo)" do
      before do
        Yast::LanItems.operation = :add
        subject.Items = mocked_items
        subject.current = 2
      end

      it "deletes the whole item" do
        subject.Rollback
        expect(subject.Items[2]).to be_nil
      end
    end

    context "when the current item is edited; (unconfigured but with hwinfo)" do
      before do
        Yast::LanItems.operation = :edit
        subject.Items = mocked_items
        subject.current = 3
      end

      context "when getNetworkInterfaces doesn't have it" do
        it "deletes the ifcfg of the item" do
          expect(subject)
            .to receive(:getNetworkInterfaces)
            .and_return(["eth1", "eth2"])
          subject.Rollback
          expect(subject.Items[3].keys).to eq(["commited", "hwinfo"])
        end
      end

      context "when getNetworkInterfaces has it" do
        it "leaves Items untouched" do
          expect(subject)
            .to receive(:getNetworkInterfaces)
            .and_return(["eth2", "eth3"])
          subject.Rollback
          expect(subject.Items).to eq(mocked_items)
        end
      end
    end
  end
end
