#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

Yast.import "Host"

describe "Host" do
  subject(:host) { Yast::Host }

  describe "#Export" do
    let(:etc_hosts) do
      {
        "127.0.0.1"  => ["localhost localhost.localdomain"],
        "10.20.1.29" => ["beholder"]
      }
    end

    it "Successfully exports stored mapping" do
      host.Import("hosts" => etc_hosts)
      expect(host.Export).to eql("hosts" => etc_hosts)
    end

    it "removes empty name lists" do
      host.Import("hosts" => { "127.0.0.1" => ["localhost"], "10.0.0.1" => [] })
      expect(host.Export).to eql("hosts" => { "127.0.0.1" => ["localhost"] })
    end

    it "exports empty hash when no mapping is defined" do
      host.Import("hosts" => {})
      expect(host.Export).to be_empty
    end
  end

  describe "#Update" do
    let(:etc_hosts) do
      {
        "127.0.0.1" => ["localhost localhost.localdomain"],
        "10.0.0.1"  => ["somehost.example.com  notice-two-spaces"]
      }
    end

    it "doesn't drop records with two spaces" do
      host.Import("hosts" => etc_hosts)
      host.Update("", "newname", ["10.0.0.42"])

      tested_ip = "10.0.0.1"
      expect(host.name_map[tested_ip]).to eql etc_hosts[tested_ip]
    end
  end
end
