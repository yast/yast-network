# Copyright (c) [2021] SUSE LLC
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
require "cfa/nm_connection"
require "cfa/memory_file"
require "y2network/connection_config/ethernet"

describe CFA::NmConnection do
  def file_path(filename)
    File.join(SCRStub::DATA_PATH, filename)
  end

  subject { described_class.new(conn_file) }
  let(:conn_file) { file_path("some_wifi.nmconnection") }

  describe ".for" do
    let(:conn) do
      Y2Network::ConnectionConfig::Ethernet.new.tap do |eth0|
        eth0.name = "eth0"
        eth0.interface = "eth0"
      end
    end

    it "uses the interface as path basename" do
      file = described_class.for(conn)
      expect(file.file_path.basename.to_s).to eq("eth0.nmconnection")
    end

    context "when a wireless connection is given" do
      let(:essid) { "MY_WIRELESS" }

      let(:conn) do
        Y2Network::ConnectionConfig::Wireless.new.tap do |wlo1|
          wlo1.name = "wlo1"
          wlo1.interface = "wlo1"
          wlo1.essid = essid
        end
      end

      context "and the ESSID is set" do
        it "uses the ESSID as path basename" do
          file = described_class.for(conn)
          expect(file.file_path.basename.to_s).to eq("MY_WIRELESS.nmconnection")
        end

        context "and the ESSID contains some '/' character" do
          let(:essid) { "MY/WIRELESS" }

          it "replaces '/' characters with '_'" do
            file = described_class.for(conn)
            expect(file.file_path.basename.to_s).to eq("MY_WIRELESS.nmconnection")
          end
        end

        context "and the ESSID starts with a dot" do
          let(:essid) { ".MY_WIRELESS" }

          it "replaces the '.' character with '_'" do
            file = described_class.for(conn)
            expect(file.file_path.basename.to_s).to eq("_MY_WIRELESS.nmconnection")
          end
        end

        context "and the ESSID ends with '~'" do
          let(:essid) { ".MY/WIRELESS~" }

          it "replaces the '~' character with '_'" do
            file = described_class.for(conn)
            expect(file.file_path.basename.to_s).to eq("_MY_WIRELESS_.nmconnection")
          end
        end

      end

      context "and the ESSID is not set" do
        let(:essid) { nil }

        it "uses the interface as path basename" do
          file = described_class.for(conn)
          expect(file.file_path.basename.to_s).to eq("wlo1.nmconnection")
        end
      end
    end
  end

  describe "#connection" do
    before { subject.load }

    it "returns the [connection] section" do
      expect(subject.connection["id"]).to eq("MyWifi")
    end

    context "when the connection section is missing" do
      let(:conn_file) { file_path("empty.nmconnection") }

      it "returns an empty connection section" do
        expect(subject.connection["id"]).to be_nil
      end
    end
  end

  describe "#exist?" do
    context "when the file exists" do
      let(:conn_file) { file_path("some_wifi.nmconnection") }

      it "returns true" do
        expect(subject.exist?).to eq(true)
      end
    end

    context "when the file does not exist" do
      let(:conn_file) { file_path("missing.nmconnection") }

      it "returns false" do
        expect(subject.exist?).to eq(false)
      end
    end
  end
end
