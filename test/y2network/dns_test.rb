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
require "y2network/dns"

describe Y2Network::DNS do
  subject(:dns) do
    described_class.new(attrs)
  end

  let(:attrs) do
    {
      resolv_conf_policy: "auto"
    }
  end

  describe "#==" do
    let(:other) { described_class.new(attrs) }

    context "given to DNS settings with the same values" do
      it "returns true" do
        expect(dns).to eq(other)
      end
    end

    context "when the resolv.conf policies are different" do
      let(:other) { described_class.new(attrs.merge(resolv_conf_policy: "another")) }

      it "returns false" do
        expect(dns).to_not eq(other)
      end
    end

    context "when the list of name servers are different" do
      let(:other) { described_class.new(attrs.merge(nameservers: ["1.1.1.1"])) }

      it "returns false" do
        expect(dns).to_not eq(other)
      end
    end

    context "when the list of domains to search are different" do
      let(:other) { described_class.new(attrs.merge(searchlist: ["example.net"])) }

      it "returns false" do
        expect(dns).to_not eq(other)
      end
    end
  end
end
