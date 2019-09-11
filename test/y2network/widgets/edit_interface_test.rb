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

require "y2network/widgets/edit_interface"
require "y2network/config"

describe Y2Network::Widgets::EditInterface do
  subject { described_class.new(table) }

  let(:selected) { "eth0" }
  let(:table) { double("table", value: selected) }
  let(:config) { Y2Network::Config.new(interfaces: interfaces, connections: connections, source: :sysconfig) }
  let(:eth0) { Y2Network::PhysicalInterface.new("eth0") }
  let(:eth1) { Y2Network::PhysicalInterface.new("eth1") }
  let(:interfaces) { Y2Network::InterfacesCollection.new([eth0, eth1]) }
  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.name = "eth0"
    end
  end
  let(:connections) { Y2Network::ConnectionConfigsCollection.new([eth0_conn]) }
  let(:sequence) { instance_double(Y2Network::Sequences::Interface, edit: nil) }

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(config)
    allow(Y2Network::Sequences::Interface).to receive(:new).and_return(sequence)
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "runs the interface edition sequence" do
      expect(sequence).to receive(:edit) do |builder|
        expect(builder.type.short_name).to eq("eth")
        expect(builder.name).to eq("eth0")
      end
      subject.handle
    end

    context "when the interface is unconfigured" do
      let(:selected) { "eth1" }

      it "runs the interface edition sequence" do
        expect(sequence).to receive(:edit) do |builder|
          expect(builder.type.short_name).to eq("eth")
          expect(builder.name).to eq("eth1")
        end
        subject.handle
      end
    end
  end
end
