#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "Host"

describe "Host#Export" do
  subject(:host) { Yast::Host }

  let(:etc_hosts) do
    {
      "127.0.0.1"  => ["localhost localhost.localdomain"],
      "10.20.1.29" => ["beholder"]
    }
  end

  it "Successfully exports stored mapping" do
    allow(host).to receive(:hosts).and_return(etc_hosts)
    expect(host.Export).to eql({ "hosts" => etc_hosts })
  end
end
