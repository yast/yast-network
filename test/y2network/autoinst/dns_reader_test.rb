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

require_relative "../../test_helper"
require "y2network/autoinst_profile/dns_section"
require "y2network/autoinst/dns_reader"
require "y2network/sysconfig/hostname_reader"

describe Y2Network::Autoinst::DNSReader do
  subject { described_class.new(dns_section) }

  let(:dns_section) do
    Y2Network::AutoinstProfile::DNSSection.new_from_hashes(dns_profile)
  end
  let(:forwarding_profile) { { "ip_forward" => true } }
  let(:dhcp_hostname) { true }
  let(:dns_profile) do
    {
      "hostname"           => "linux.example.org",
      "nameservers"        => ["192.168.122.1", "10.0.0.1"],
      "searchlist"         => ["suse.com"],
      "resolv_conf_policy" => "some-policy"
    }
  end
  let(:hostname_reader) { instance_double(Y2Network::Sysconfig::HostnameReader, hostname: "foo") }

  before do
    allow(Y2Network::Sysconfig::HostnameReader).to receive(:new).and_return(hostname_reader)
  end

  describe "#config" do
    EMPTY_DNS_SECTION = Y2Network::AutoinstProfile::DNSSection.new_from_hashes({})

    it "builds a new Y2Network::DNS config from the profile" do
      expect(subject.config).to be_a Y2Network::DNS
      expect(subject.config.resolv_conf_policy).to eq("some-policy")
      expect(subject.config.nameservers.size).to eq(2)
    end

    it "falls back to 'auto' for resolv_conf_policy" do
      config = described_class.new(EMPTY_DNS_SECTION).config
      expect(config.resolv_conf_policy).to eq("auto")
    end

    it "falls back to an empty array for the name servers" do
      config = described_class.new(EMPTY_DNS_SECTION).config
      expect(config.nameservers).to eq([])
    end

    it "falls back to an empty array for the search list" do
      config = described_class.new(EMPTY_DNS_SECTION).config
      expect(config.searchlist).to eq([])
    end
  end
end
