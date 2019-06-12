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
require "y2network/config_reader/autoinst_dns"

describe Y2Network::ConfigReader::AutoinstDNS do
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
      "resolv_conf_policy" => "auto"
    }
  end

  describe "#config" do
    it "builds a new Y2Network::DNS config from the profile" do
      expect(subject.config).to be_a Y2Network::DNS
      expect(subject.config.hostname).to eq("linux.example.org")
      expect(subject.config.resolv_conf_policy).to eq("auto")
      expect(subject.config.nameservers.size).to eq(2)
    end
  end
end
