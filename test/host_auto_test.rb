#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require_relative "../src/clients/host_auto"

describe Yast::HostAutoClient do
  describe "#main" do
    before do
      allow(Yast::WFM).to receive(:Args).with(no_args).and_return([func,hosts])
      allow(Yast::WFM).to receive(:Args).with(0).and_return(func)
      allow(Yast::WFM).to receive(:Args).with(1).and_return(hosts)
    end

    context "when func is Import" do
      let(:func) { "Import" }
      let(:i_list) { double("IssuesList", add: nil) }
      let(:hosts) { {"hosts" =>[{"host_address" => "10.20.1.29", "names" => [" "] }]} }

      it "blames empty host name entries" do
        expect(Yast::AutoInstall).to receive(:issues_list).and_return(i_list)
        expect(i_list).to receive(:add)
          .with(:invalid_value,
            "host",
            "names",
            "",
            "The name must not be empty for 10.20.1.29.")
        expect(subject.main).to eq(true)
      end
    end
  end
end
