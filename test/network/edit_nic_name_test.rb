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

require_relative "../test_helper"

require "yast"
require "network/edit_nic_name"

require "y2network/route"
require "y2network/routing"
require "y2network/routing_table"
require "y2network/interfaces_collection"
require "y2network/interface"
require "y2network/interface_config_builder"
require "y2network/config"

Yast.import "LanItems"

describe Yast::EditNicName do
  let(:subject) { described_class.new(builder) }
  let(:current_name) { "spec0" }
  let(:new_name) { "new1" }
  let(:existing_new_name) { "existing_new_name" }
  let(:interface_hwinfo) { { "dev_name" => current_name, "permanent_mac" => "00:01:02:03:04:05" } }

  let(:route1) { Y2Network::Route.new }
  let(:table1) { Y2Network::RoutingTable.new(routes: [route1]) }
  let(:routing) { Y2Network::Routing.new(tables: table1) }
  let(:iface) { Y2Network::Interface.new(current_name) }
  let(:ifaces) { Y2Network::InterfacesCollection.new([iface]) }
  let(:yast_config) do
    Y2Network::Config.new(interfaces: ifaces, routing: routing, source: :sysconfig)
  end
  let(:builder) do
    instance_double(Y2Network::InterfaceConfigBuilder, interface: iface,
      name_exists?: false, valid_name?: true, rename_interface: nil)
  end

  before do
    allow(Y2Network::Config).to receive(:find).and_return(yast_config)
  end

  describe "#run" do
    # general mocking stuff is placed here
    before(:each) do
      # NetworkInterfaces are too low level. Everything needed should be mocked
      stub_const("NetworkInterfaces", double(adapt_old_config!: nil))

      # mock devices configuration
      allow(Yast::LanItems).to receive(:ReadHardware).and_return([interface_hwinfo])
      allow(Yast::LanItems).to receive(:getNetworkInterfaces).and_return([current_name])
      allow(Yast::LanItems).to receive(:GetItemUdev) { "" }
      allow(Yast::LanItems).to receive(:current_udev_name).and_return(current_name)
      allow(Yast::LanItems).to receive(:GetItemUdev).with("ATTR{address}") { "00:01:02:03:04:05" }
      allow(Yast::LanItems).to receive(:GetNetcardNames).and_return([current_name])

      # LanItems initialization

      Yast::LanItems.Read
      Yast::LanItems.FindAndSelect(current_name)
    end

    context "when closed without any change" do
      before(:each) do
        # emulate Yast::UI work
        allow(Yast::UI).to receive(:QueryWidget).with(:dev_name, :Value) { current_name }
        allow(Yast::UI).to receive(:QueryWidget).with(:udev_type, :CurrentButton) { :mac }
        allow(Yast::UI).to receive(:UserInput) { :ok }
        allow(Yast::LanItems).to receive(:update_item_udev_rule!)
      end

      it "returns current name when used Ok button" do
        expect(subject.run).to be_equal current_name
      end

      it "returns current name when used Cancel button" do
        allow(Yast::UI).to receive(:UserInput) { :cancel }

        expect(subject.run).to be_equal current_name
      end
    end

    context "when name changed" do
      before(:each) do
        # emulate Yast::UI work
        allow(Yast::UI).to receive(:QueryWidget).with(:dev_name, :Value) { new_name }
        allow(Yast::UI).to receive(:QueryWidget).with(:udev_type, :CurrentButton) { :mac }
        allow(Yast::UI).to receive(:UserInput) { :ok }
        allow(subject).to receive(:update_routes?).and_return(false)
      end

      context "and closed confirming the changes" do
        it "returns the new name" do
          expect(subject.run).to be_equal new_name
        end

        it "asks for new user input when name already exists" do
          allow(Yast::UI).to receive(:QueryWidget)
            .with(:dev_name, :Value).and_return(existing_new_name, new_name)
          allow(subject).to receive(:CheckUdevNicName).with(existing_new_name).and_return(false)
          allow(subject).to receive(:CheckUdevNicName).with(new_name).and_return(true)
          allow(Yast::UI).to receive(:SetFocus)
          expect(builder).to receive(:rename_interface).with(new_name, :mac)
          subject.run
        end

        context "but used the same matching udev key" do
          it "does not touch the current udev rule" do
            expect(Yast::LanItems).to_not receive(:update_item_udev_rule!)
          end
        end

        xcontext "and there are some routes referencing the previous name" do
          before do
            allow(Yast::Routing).to receive(:device_routes?).with(current_name).and_return(true)
            expect(subject).to receive(:update_routes?).with(current_name).and_call_original
            allow(Yast::LanItems).to receive(:update_routes!).with(current_name)
          end

          it "asks the user about updating the routes device name" do
            expect(Yast::Popup).to receive(:YesNoHeadline)

            subject.run
          end

          it "updates the routes if the user accepts to do it" do
            expect(Yast::Popup).to receive(:YesNoHeadline).and_return(true)
            expect(Yast::LanItems).to receive(:update_routes!).with(current_name)

            subject.run
          end

          it "does not touch the routes if the user does not want to touch them" do
            expect(Yast::Popup).to receive(:YesNoHeadline).and_return(false)
            expect(Yast::LanItems).to_not receive(:update_routes!)
            subject.run
          end
        end

        context "having modified the matching udev key" do
          before(:each) do
            # emulate UI work
            allow(Yast::UI).to receive(:QueryWidget).with(:dev_name, :Value) { current_name }
            allow(Yast::UI).to receive(:QueryWidget).with(:udev_type, :CurrentButton) { :bus_id }
          end

          it "updates the current udev rule with the key used" do
            expect(Yast::LanItems).to_not receive(:update_item_udev_rule!).with(:bus_id)
          end
        end
      end

      context "and closed canceling the changes" do
        it "returns current name when used Cancel button" do
          allow(Yast::UI).to receive(:UserInput) { :cancel }

          expect(subject.run).to be_equal current_name
        end
      end
    end
  end
end
