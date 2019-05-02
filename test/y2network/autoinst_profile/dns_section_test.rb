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
require "y2network/dns"

describe Y2Network::AutoinstProfile::DNSSection do
  subject(:section) { described_class.new }

  describe ".new_from_network" do
    let(:dns) do
      instance_double(
        Y2Network::DNS, hostname: "linux", dhcp_hostname: true, resolv_conf_policy: "auto",
        name_servers: name_servers, search_domains: search_domains
      )
    end

    let(:name_servers) { [IPAddr.new("1.1.1.1")] }
    let(:search_domains) { ["example.net"] }

    it "sets the hostname attribute" do
      section = described_class.new_from_network(dns)
      expect(section.hostname).to eq("linux")
    end

    it "sets the dhcp_hostname attribute" do
      section = described_class.new_from_network(dns)
      expect(section.dhcp_hostname).to eq(true)
    end

    it "sets the resolv_conf_policy attribute" do
      section = described_class.new_from_network(dns)
      expect(section.resolv_conf_policy).to eq("auto")
    end

    it "sets the nameservers attribute" do
      section = described_class.new_from_network(dns)
      expect(section.nameservers).to eq(["1.1.1.1"])
    end

    it "sets the searchlist attribute" do
      section = described_class.new_from_network(dns)
      expect(section.searchlist).to eq(["example.net"])
    end
  end
end
