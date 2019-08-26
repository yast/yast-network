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

require "y2network/dialogs/rename_interface"
require "y2network/interface_config_builder"
require "y2network/widgets/custom_interface_name"
require "y2network/widgets/rename_hwinfo"
require "y2network/physical_interface"

describe Y2Network::Dialogs::RenameInterface do
  subject { described_class.new(builder) }

  let(:builder) do
    Y2Network::InterfaceConfigBuilder.for("eth").tap do |builder|
      builder.name = "eth0"
    end
  end

  let(:name_widget) do
    Y2Network::Widgets::CustomInterfaceName.new(builder)
  end

  let(:rename_hwinfo_widget) do
    Y2Network::Widgets::RenameHwinfo.new(builder)
  end

  let(:interface) do
    Y2Network::PhysicalInterface.new("eth0")
  end

  let(:hardware) do
    Y2Network::Hwinfo.new(mac: "01:23:45:67:89:ab", busid: "0000:08:00.0")
  end

  let(:rename_hwinfo) do
    Y2Network::Hwinfo.new(mac: "01:23:45:67:89:ab")
  end

  let(:new_name) { "eth1" }

  let(:result) { :ok }

  include_examples "CWM::Dialog"

  before do
    allow(builder).to receive(:interface).and_return(interface)
    allow(subject).to receive(:cwm_show).and_return(result)
    allow(Y2Network::Widgets::CustomInterfaceName).to receive(:new).and_return(name_widget)
    allow(Y2Network::Widgets::RenameHwinfo).to receive(:new).and_return(rename_hwinfo_widget)
    allow(name_widget).to receive(:value).and_return(new_name)
    allow(rename_hwinfo_widget).to receive(:value).and_return(rename_hwinfo)
    allow(interface).to receive(:hardware).and_return(hardware)
  end

  describe "#run" do
    before do
      allow(Yast::UI).to receive(:UserInput).and_return(:ok)
    end

    context "when the user accepts the change" do
      let(:result) { :ok }

      it "renames the interface" do
        expect(builder).to receive(:rename_interface)
          .with(new_name, rename_hwinfo)
        subject.run
      end
    end

    context "when the user clicks the cancel button" do
      let(:result) { :cancel }

      it "doest not rename the interface" do
        expect(builder).to_not receive(:rename_interface)
        subject.run
      end
    end
  end
end
