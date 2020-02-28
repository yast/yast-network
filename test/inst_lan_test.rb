#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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
require "network/clients/inst_lan"

describe Yast::InstLanClient do
  describe "#main" do
    let(:argmap) { { "skip_detection" => force_config } }
    let(:force_config) { false }
    let(:config) { nil }
    let(:going_back) { false }
    let(:using_nm) { false }
    let(:connections) { Y2Network::ConnectionConfigsCollection.new([]) }
    let(:fake_conn) { instance_double("Y2Network::ConnectionConfig") }

    before do
      allow(Yast::GetInstArgs).to receive(:argmap).and_return(argmap)
      allow(Yast::Lan).to receive(:yast_config).and_return(config)
      allow(Yast::Lan).to receive(:Read)
      allow(subject).to receive(:LanSequence)
      allow(Yast::GetInstArgs).to receive(:going_back).and_return(going_back)
      allow(Yast::NetworkService).to receive(:network_manager?).and_return(using_nm)
      subject.send(:reset_config_state)
    end

    context "when the network was already configured by the client" do
      before do
        allow(subject).to receive(:network_configured?).and_return(true)
      end

      context "but a manual configuration is forced" do
        let(:force_config) { true }

        it "runs the network configuration sequence" do
          expect(subject).to receive(:LanSequence)
          subject.main
        end
      end

      context "and a manual configuration is not forced" do
        it "does not run the network configuration sequence" do
          expect(subject).to_not receive(:LanSequence)

          subject.main
        end

        it "returns :auto" do
          expect(subject.main).to eq(:auto)
        end
      end
    end

    context "when the NetworkService is NetworkManager" do
      let(:using_nm) { true }

      it "does not run the network configuration sequence" do
        expect(subject).to_not receive(:LanSequence)
        subject.main
      end
    end

    context "when the NetworkService is wicked" do
      it "reads the current network config" do
        expect(Yast::Lan).to receive(:Read).with(:cache)

        subject.main
      end

      context "and there is some connection config already present in yast" do
        let(:connections) { Y2Network::ConnectionConfigsCollection.new([fake_conn]) }
        let(:config) { instance_double("Y2Network::Config", connections: connections) }

        it "does not run the network configuration sequence" do
          expect(subject).to_not receive(:LanSequence)

          subject.main
        end
      end

      context "and the network is unconfigured" do
        it "runs the network configuration sequence" do
          expect(subject).to receive(:LanSequence)
          subject.main
        end
      end
    end
  end
end
