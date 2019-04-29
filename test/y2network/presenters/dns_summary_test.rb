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
require "y2network/presenters/dns_summary"
require "y2network/dns"

describe Y2Network::Presenters::DNSSummary do
  subject(:presenter) { described_class.new(dns) }

  let(:dns) do
    Y2Network::DNS.new(
      hostname: hostname, name_servers: name_servers, search_domains: search_domains
    )
  end
  let(:hostname) { "test" }
  let(:name_servers) { [IPAddr.new("1.1.1.1"), IPAddr.new("8.8.8.8")] }
  let(:search_domains) { ["example.net", "example.org"] }

  describe "#text" do
    it "returns a summary in text form" do
      text = presenter.text
      expect(text).to include("Hostname: test")
      expect(text).to include("Name Servers: 1.1.1.1, 8.8.8.8")
      expect(text).to include("Search List: example.net, example.org")
    end

    context "when no hostname is given" do
      let(:hostname) { "" }

      it "does not show the hostname" do
        text = presenter.text
        expect(text).to_not include("Hostname")
      end
    end

    context "when name servers are given" do
      let(:name_servers) { [] }

      it "does not show the name servers" do
        text = presenter.text
        expect(text).to_not include("Name Servers")
      end
    end

    context "when search domains are given" do
      let(:search_domains) { [] }

      it "does not show the search domains" do
        text = presenter.text
        expect(text).to_not include("Search List")
      end
    end
  end
end
