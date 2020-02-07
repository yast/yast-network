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

require_relative "../../test_helper"

require "y2network/config"
require "y2network/presenters/proposal_summary"
require "y2network/presenters/interfaces_summary"
require "y2network/presenters/routing_summary"
require "y2network/presenters/dns_summary"

describe Y2Network::Presenters::ProposalSummary do
  subject(:presenter) { described_class.new(config) }

  let(:config) { double.as_null_object }

  let(:interfaces_summary) do
    double(
      Y2Network::Presenters::InterfacesSummary,
      text:          "nterfaces_summary",
      one_line_text: "interfaces_summary_one_line",
      proposal_text: "interfaces_proposal_summary"
    )
  end

  let(:dns_summary) do
    double(Y2Network::Presenters::DNSSummary, text: "dns_summary")
  end
  let(:routing_summary) do
    double(Y2Network::Presenters::RoutingSummary, text: "routing_summary")
  end

  before do
    allow(presenter).to receive(:interfaces_summary).and_return(interfaces_summary)
    allow(presenter).to receive(:dns_summary).and_return(dns_summary)
    allow(presenter).to receive(:routing_summary).and_return(routing_summary)
  end

  describe "#text" do
    it "returns a summary in text form" do
      text = presenter.text
      expect(text).to be_a(::String)
    end

    it "returns a summary with the interfaces, dns and routing configuration" do
      expect(presenter.text).to include("<li>Interfaces</li>interfaces_proposal_summary")
      expect(presenter.text).to include("<li>Hostname / DNS</li>dns_summary")
      expect(presenter.text).to include("<li>Routing</li>routing_summary")
    end
  end
end
