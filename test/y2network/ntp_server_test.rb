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

require_relative "../test_helper"

require "y2network/ntp_server"

describe Y2Network::NtpServer do
  describe ".default_servers" do
    before do
      allow(Yast::Product).to receive(:FindBaseProducts)
        .and_return(products)
    end

    context "when running in an openSUSE system" do
      let(:products) do
        [{ "name" => "openSUSE" }]
      end

      it "returns a set of opensuse.pool.ntp.org servers" do
        domain = "opensuse.pool.ntp.org"
        expect(described_class.default_servers.map(&:hostname)).to eq(
          ["0.#{domain}", "1.#{domain}", "2.#{domain}", "3.#{domain}"]
        )
      end
    end

    context "when not running in an openSUSE system" do
      let(:products) do
        [{ "name" => "SLES" }]
      end

      it "returns a set of suse.pool.ntp.org servers" do
        domain = "suse.pool.ntp.org"
        expect(described_class.default_servers.map(&:hostname)).to eq(
          ["0.#{domain}", "1.#{domain}", "2.#{domain}", "3.#{domain}"]
        )
      end
    end

    context "when a list of base product is given" do
      let(:products) do
        [{ "name" => "openSUSE" }]
      end

      it "returns the set of servers for that product" do
        domain = "opensuse.pool.ntp.org"
        expect(Yast::Product).to_not receive(:FindBaseProducts)
        servers = described_class.default_servers(products)
        expect(servers.map(&:hostname)).to eq(
          ["0.#{domain}", "1.#{domain}", "2.#{domain}", "3.#{domain}"]
        )
      end
    end
  end

  describe "#==" do
    subject { Y2Network::NtpServer.new("suse.pool.ntp.org", country: "DE", location: "Germany") }

    let(:other) do
      Y2Network::NtpServer.new(other_hostname, country: other_country, location: other_location)
    end
    let(:other_hostname) { subject.hostname }
    let(:other_country) { subject.country }
    let(:other_location) { subject.location }

    context "when both objects contain the same information" do
      it "returns true" do
        expect(subject).to eq(other)
      end
    end

    context "when the hostname is different" do
      let(:other_hostname) { "opensuse.pool.ntp.org" }

      it "returns false" do
        expect(subject).to_not eq(other)
      end
    end

    context "when the country is different" do
      let(:other_country) { "ES" }

      it "returns false" do
        expect(subject).to_not eq(other)
      end
    end

    context "when the hostname is different" do
      let(:other_location) { "Spain" }

      it "returns false" do
        expect(subject).to_not eq(other)
      end
    end

  end
end
