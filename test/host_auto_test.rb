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

require_relative "test_helper"

require "yast"
require_relative "../src/clients/host_auto"

describe Yast::HostAutoClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return([func, hosts])
      allow(Yast::WFM).to receive(:Args).with(0).and_return(func)
      allow(Yast::WFM).to receive(:Args).with(1).and_return(hosts)
    end

    context "when func is Import" do
      let(:func) { "Import" }
      let(:i_list) { double("IssuesList", add: nil) }
      let(:hosts) { { "hosts" =>[{ "host_address" => "10.20.1.29", "names" => [" "] }] } }

      it "blames empty host name entries" do
        expect(Yast::AutoInstall).to receive(:issues_list).and_return(i_list)
        expect(i_list).to receive(:add)
          .with(::Y2Autoinstallation::AutoinstIssues::AyInvalidValue,
            "host",
            "names",
            "",
            "The name must not be empty for 10.20.1.29.")
        expect(subject.main).to eq(true)
      end
    end
  end
end
