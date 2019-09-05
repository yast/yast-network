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
require "y2network/hostname_reader"

describe Y2Network::HostnameReader do
  subject(:reader) { described_class.new }

  describe "#hostname" do
    let(:executor) do
      double("Yast::Execute", on_target!: "")
    end

    before do
      allow(Yast::Execute).to receive(:stdout).and_return(executor)
    end

    it "returns the hostname" do
      expect(executor).to receive(:on_target!).with(/hostname/).and_return("foo")
      expect(reader.hostname).to eq("foo")
    end

    context "during installation" do
      before do
        allow(Yast::Mode).to receive(:installation).and_return(true)
        allow(Yast::FileUtils).to receive(:Exists).with("/etc/install.inf")
          .and_return(install_inf_exists)
        allow(Yast::SCR).to receive(:Read).and_return(hostname)
        allow(executor).to receive(:on_target!).with(/hostname/).and_return("foo")
      end

      let(:hostname) { "linuxrc.example.net" }
      let(:install_inf_exists) { true }

      it "reads the hostname from /etc/install.conf" do
        expect(reader.hostname).to eq("linuxrc")
      end

      context "and the hostname from /etc/install.conf is an IP address" do
        let(:hostname) { "192.168.122.1" }

        before do
          allow(Yast::NetHwDetection).to receive(:ResolveIP).with(hostname)
            .and_return("router")
        end

        it "returns the name for the address" do
          expect(reader.hostname).to eq("router")
        end
      end

      context "and the hostname is not defined in /etc/install.conf" do
        let(:hostname) { nil }

        it "reads the hostname from the system" do
          expect(reader.hostname).to eq("foo")
        end
      end

      context "and the /etc/install.inf file does not exists" do
        let(:install_inf_exists) { false }

        it "reads the hostname from the system" do
          expect(reader.hostname).to eq("foo")
        end
      end
    end
  end
end
