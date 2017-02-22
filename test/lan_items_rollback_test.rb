#!/usr/bin/env rspec

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
    context "when the current item is committed" do
      before do
        subject.Items = mocked_items
        subject.current = 1
      end

      it "leaves Items untouched" do
        subject.Rollback
        expect(subject.Items).to eq(mocked_items)
      end
    end

    context "when the current item is uncommitted; without hwinfo" do
      before do
        subject.Items = mocked_items
        subject.current = 2
      end

      it "deletes the whole item" do
        subject.Rollback
        expect(subject.Items[2]).to be_nil
      end
    end

    context "when the current item is uncommitted; with hwinfo" do
      before do
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
