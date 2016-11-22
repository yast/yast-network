#!/usr/bin/env rspec

require_relative "../test_helper"
require "cfa/hosts"
require "cfa/memory_file"

describe CFA::Hosts do
  subject(:hosts) { CFA::Hosts.new(file_handler: File) }
  let(:file_path) { File.join(SCRStub::DATA_PATH, "hosts") }

  before { stub_const("CFA::Hosts::PATH", file_path) }

  describe "#hosts" do
    it "returns an empty hash when data isn't loaded" do
      expect(hosts.hosts).to eq({})
    end

    it "returns hosts in the /etc/hosts" do
      hosts.load
      all_hosts = hosts.hosts
      expect(all_hosts.size).to eq(11)
      expect(all_hosts["10.100.128.72"]).to eq(["pepa.labs.suse.cz pepa pepa2"])
      expect(all_hosts["10.100.128.1"]).to eq(["gw.labs.suse.cz", "gw1.labs.suse.cz gw1"])
    end
  end

  describe "#host" do
    before { hosts.load }
    let(:ip) { "10.100.128.72" }

    it "returns the hostnames for a given IP" do
      expect(hosts.host(ip)).to eq(["pepa.labs.suse.cz pepa pepa2"])
    end

    context "if a given IP is not defined" do
      let(:ip) { "10.10.10.10" }

      it "returns an empty array" do
        expect(hosts.host(ip)).to eq([])
      end
    end
  end

  describe "#delete_by_ip" do
    before { hosts.load }
    let(:ip) { "127.0.0.2" }

    it "returns the host names for a given IP" do
      expect { hosts.delete_by_ip(ip) }.to change { hosts.host(ip) }
        .from(["localhost"]).to([])
    end

    context "if a given IP is not defined" do
      let(:ip) { "10.10.10.10" }

      it "returns an empty array" do
        expect { hosts.delete_by_ip(ip) }.to_not change { hosts.hosts }
      end
    end
  end

  describe "#set_entry" do
    before { hosts.load }

    it "updates the entry" do
      hosts.set_entry("127.0.0.1", "localhost.localdomain", ["mylocalhost"])
      expect(hosts.host("127.0.0.1")).to eq(["localhost.localdomain mylocalhost"])
    end

    context "if the entry does not exist" do
      it "adds the entry" do
        expect(hosts).to receive(:add_entry).with("10.10.10.10", "new-host", ["new-host.localdomain"])
        hosts.set_entry("10.10.10.10", "new-host", ["new-host.localdomain"])
      end
    end
  end

  describe "#add_entry" do
    it "adds the entry" do
      hosts.set_entry("10.10.10.10", "new-host.localdomain", ["new-host newhost"])
      expect(hosts.host("10.10.10.10")).to eq(["new-host.localdomain new-host newhost"])
    end
  end

  describe "#delete_hostname" do
    before { hosts.load }

    context "if the entry only has a canonical name" do
      it "removes the entry" do
        hosts.delete_hostname("gw.labs.suse.cz")
        expect(hosts.host("10.100.128.1")).to eq([])
      end
    end

    context "if the entry has some alias" do
      it "sets the first alias as the hostname" do
        hosts.delete_hostname("pepa.labs.suse.cz")
        expect(hosts.host("10.100.128.72")).to eq(["pepa pepa2"])
      end
    end

    context "given an alias" do
      it "removes the alias" do
        hosts.delete_hostname("pepa")
        expect(hosts.host("10.100.128.72")).to eq(["pepa.labs.suse.cz pepa2"])
      end
    end
  end

  describe "#include_ip?" do
    before { hosts.load }

    context "when the IP is defined" do
      it "returns true" do
        expect(hosts.include_ip?("127.0.0.1")).to eq(true)
      end
    end

    context "when the IP is defined" do
      it "returns false" do
        expect(hosts.include_ip?("10.10.10.10")).to eq(false)
      end
    end
  end
end
