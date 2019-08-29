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
require "cwm/rspec"

require "y2network/widgets/udev_rules"
require "y2network/dialogs/rename_interface"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::UdevRules do
  subject { described_class.new(builder) }

  let(:builder) { instance_double(Y2Network::InterfaceConfigBuilder, name: "eth0") }
  let(:dialog_ret) { :ok }
  let(:dialog) { instance_double(Y2Network::Dialogs::RenameInterface, run: dialog_ret) }

  before do
    allow(Yast::LanItems).to receive(:current_udev_name).and_return("hell666")
    allow(Y2Network::Dialogs::RenameInterface).to receive(:new).and_return(dialog)
  end

  include_examples "CWM::CustomWidget"
  include Yast::UIShortcuts

  describe "#init" do
    it "initializes the input field with the current name" do
      expect(subject).to receive(:value=).with("eth0")
      subject.init
    end
  end

  describe "#handle" do
    it "opens the rename interface dialog" do
      expect(dialog).to receive(:run)
      subject.handle
    end

    context "when the dialog returns :ok" do
      it "updates the current value" do
        expect(subject).to receive(:value=).with(builder.name)
        subject.handle
      end
    end

    context "when the dialog does not returns :ok" do
      let(:dialog_ret) { :cancel }

      it "does not update the current value" do
        expect(subject).to_not receive(:value=)
        subject.handle
      end
    end
  end

  describe "#value=" do
    it "updates the input field with the given name" do
      expect(Yast::UI).to receive(:ChangeWidget).with(Id(:udev_rules_name), :Value, "eth1")
      subject.value = "eth1"
    end
  end

  describe "#value" do
    before do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(:udev_rules_name), :Value).and_return("eth1")
    end

    it "returns the value from the input field" do
      expect(subject.value).to eq("eth1")
    end
  end
end
