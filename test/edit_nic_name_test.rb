#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/edit_nic_name"

module Yast
  Yast.import "UI"

  CURRENT_NAME = "spec0".freeze
  NEW_NAME = "new1".freeze
  EXISTING_NEW_NAME = "existing_new_name".freeze

  describe "#run" do
    # general mocking stuff is placed here
    before(:each) do
      # NetworkInterfaces are too low level. Everything needed should be mocked
      stub_const("NetworkInterfaces", double(adapt_old_config!: nil))

      # mock devices configuration
      allow(LanItems).to receive(:ReadHardware) { [{ "dev_name" => CURRENT_NAME, "mac" => "00:01:02:03:04:05" }] }
      allow(LanItems).to receive(:getNetworkInterfaces) { [CURRENT_NAME] }
      allow(LanItems).to receive(:GetItemUdev) { "" }
      allow(LanItems).to receive(:GetItemUdev).with("NAME") { CURRENT_NAME }
      allow(LanItems).to receive(:GetItemUdev).with("ATTR{address}") { "00:01:02:03:04:05" }

      # LanItems initialization
      Yast.import "LanItems"

      LanItems.Read
      LanItems.FindAndSelect(CURRENT_NAME)

      # create the dialog
      @edit_name_dlg = EditNicName.new

      allow(LanItems)
        .to receive(:GetNetcardNames)
        .and_return([CURRENT_NAME])
    end

    context "when closed without any change" do
      before(:each) do
        # emulate UI work
        allow(UI).to receive(:QueryWidget).with(:dev_name, :Value) { CURRENT_NAME }
        allow(UI).to receive(:QueryWidget).with(:udev_type, :CurrentButton) { :mac }
      end

      it "returns current name when used Ok button" do
        allow(UI).to receive(:UserInput) { :ok }

        expect(@edit_name_dlg.run).to be_equal CURRENT_NAME
      end

      it "returns current name when used Cancel button" do
        allow(UI).to receive(:UserInput) { :cancel }

        expect(@edit_name_dlg.run).to be_equal CURRENT_NAME
      end
    end

    context "when closed after name change" do
      before(:each) do
        # emulate UI work
        allow(UI).to receive(:QueryWidget).with(:dev_name, :Value) { NEW_NAME }
        allow(UI).to receive(:QueryWidget).with(:udev_type, :CurrentButton) { :mac }
      end

      it "returns new name when used Ok button" do
        allow(UI).to receive(:UserInput) { :ok }

        expect(@edit_name_dlg.run).to be_equal NEW_NAME
      end

      it "returns current name when used Cancel button" do
        allow(UI).to receive(:UserInput) { :cancel }

        expect(@edit_name_dlg.run).to be_equal CURRENT_NAME
      end

      it "asks for new user input when name already exists" do
        allow(UI)
          .to receive(:QueryWidget)
          .with(:dev_name, :Value)
          .and_return(EXISTING_NEW_NAME, NEW_NAME)
        allow(UI)
          .to receive(:UserInput)
          .and_return(:ok)

        expect(@edit_name_dlg)
          .to receive(:check_new_device_name)
          .with(EXISTING_NEW_NAME)
          .and_return(false)
        expect(@edit_name_dlg)
          .to receive(:check_new_device_name)
          .with(NEW_NAME)
          .and_return(true)

        expect(UI)
          .to receive(:SetFocus)
        expect(LanItems)
          .to receive(:rename)
          .with(NEW_NAME)

        expect(@edit_name_dlg.run).to eql NEW_NAME
      end
    end
  end
end
