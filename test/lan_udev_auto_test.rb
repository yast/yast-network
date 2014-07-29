#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"

module Yast

  Yast.import "UI"

  NEW_STYLE_NAME = "spec0"
  MAC_BASED_NAME = "spec-id-00:11:22:33:44:FF"
  BUS_BASED_NAME = "spec-bus-0000:00:19.0"

  LCASE_MAC_NAME = "spec-id-00:11:22:33:44:ff"

  UNKNOWN_MAC_NAME = "spec-id-00:00:00:00:00:00"
  UNKNOWN_BUS_NAME = "spec-bus-0000:00:00.0"

  INVALID_NAME = "some funny string"

  describe '#getDeviceName' do
    # general mocking stuff is placed here
    before( :each) do
      # mock devices configuration
      Yast.import "LanUdevAuto"

      LanUdevAuto.stub( :ReadHardware) {
        [
          {
            "dev_name" => NEW_STYLE_NAME,
            "mac" => "00:11:22:33:44:FF",
            "busid" => "0000:00:19.0"
          }
        ]
      }
    end

    context 'when new style name is provided' do
      it 'returns the new style name' do
        expect( LanUdevAuto.getDeviceName( NEW_STYLE_NAME)).to be_equal NEW_STYLE_NAME
      end
    end

    context 'when old fashioned mac based name is provided' do
      it 'returns corresponding new style name' do
        expect( LanUdevAuto.getDeviceName( MAC_BASED_NAME)).to be_equal NEW_STYLE_NAME
      end

      it 'returns same result despite of letter case in mac' do
        expect(
          LanUdevAuto.getDeviceName( LCASE_MAC_NAME)
        ).to be_equal LanUdevAuto.getDeviceName( MAC_BASED_NAME)
      end

      it 'returns given name if no known device is matched' do
        expect( LanUdevAuto.getDeviceName( UNKNOWN_MAC_NAME)).to be_equal UNKNOWN_MAC_NAME
      end
    end

    context 'when old fashioned bus id based name is provided' do
      it 'returns corresponding new style name' do
        expect( LanUdevAuto.getDeviceName( BUS_BASED_NAME)).to be_equal NEW_STYLE_NAME
      end

      it 'returns given name if no known device is matched' do
        expect( LanUdevAuto.getDeviceName( UNKNOWN_MAC_NAME)).to be_equal UNKNOWN_MAC_NAME
      end
    end

    context 'when provided invalid input' do
      # TODO: should raise an exception in future
      it 'returns given input' do
        expect( LanUdevAuto.getDeviceName( INVALID_NAME)).to be_equal INVALID_NAME
      end
    end

  end
end
