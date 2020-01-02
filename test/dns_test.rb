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

require "y2network/type_detector"
require "y2network/interface_type"

Yast.import "Arch"
Yast.import "DNS"
Yast.import "ProductControl"
Yast.import "Lan"

describe Yast::DNS do
  let(:lan_config) do
    Y2Network::Config.new(dns: dns_config, hostname: hostname_config, source: :sysconfig)
  end
  let(:dns_config) do
    Y2Network::DNS.new
  end
  let(:hostname_config) do
    Y2Network::Hostname.new(static: "install", dhcp_hostname: true)
  end

  subject { Yast::DNS }

  before do
    allow(Yast::Lan).to receive(:Read)
    allow(Yast::Lan).to receive(:yast_config).and_return(lan_config)
  end

  describe ".default_dhcp_hostname" do
    before do
      allow(Yast::Arch).to receive(:is_laptop).and_return laptop
      Yast::ProductControl.ReadControlFile(File.join(SCRStub::DATA_PATH, control_file))
    end

    context "with dhcp_hostname=true in control file" do
      let(:control_file) { "dhcp_hostname_true.xml" }

      context "in a laptop" do
        let(:laptop) { true }

        it "returns the value from product features" do
          expect(subject.default_dhcp_hostname).to eql(true)
        end
      end

      context "in a workstation" do
        let(:laptop) { false }

        it "returns the value from product features" do
          expect(subject.default_dhcp_hostname).to eql(true)
        end
      end
    end

    context "with dhcp_hostname=false in control file" do
      let(:control_file) { "dhcp_hostname_false.xml" }

      context "in a laptop" do
        let(:laptop) { true }

        it "returns the value from product features" do
          expect(subject.default_dhcp_hostname).to eql(false)
        end
      end

      context "in a workstation" do
        let(:laptop) { false }

        it "returns the value from product features" do
          expect(subject.default_dhcp_hostname).to eql(false)
        end
      end
    end

    context "without dhcp_hostname in control file" do
      let(:control_file) { "dhcp_hostname_nil.xml" }

      context "in a laptop" do
        let(:laptop) { true }

        it "returns false" do
          expect(subject.default_dhcp_hostname).to eql(false)
        end
      end

      context "in a workstation" do
        let(:laptop) { false }

        it "returns true" do
          expect(subject.default_dhcp_hostname).to eql(true)
        end
      end
    end
  end

  describe ".IsHostLocal" do
    let(:ip) { "10.111.66.75" }
    let(:hostname_short) { "test" }
    let(:hostname_fq) { "test.test.de" }
    let(:output) do
      { "ip" => ip, "hostname_short" => hostname_short, "hostname_fq" => hostname_fq }
    end
    let(:ipv4) { false }
    let(:ipv6) { false }
    let(:stdout) { double }

    before do
      allow(Y2Network::TypeDetector)
        .to receive(:type_of)
        .with(/eth[0-9]/)
        .and_return(Y2Network::InterfaceType::ETHERNET)
      allow(subject).to receive(:Read)
      allow(Yast::IP).to receive(:Check4).and_return(ipv4)
      allow(Yast::IP).to receive(:Check6).and_return(ipv6)
      allow(Yast::Execute).to receive(:stdout).and_return(stdout)
      allow(stdout).to receive(:on_target!).with("/usr/bin/hostname -i").and_return(ip)
      allow(stdout).to receive(:on_target!).with("/usr/bin/hostname").and_return(hostname_short)
      allow(stdout).to receive(:on_target!).with("/usr/bin/hostname -f").and_return(hostname_fq)

      subject.dhcp_hostname = true
    end

    ["localhost", "localhost.localdomain", "::1", "127.0.0.1"].each do |host|
      it "returns true when host is \"#{host}\"" do
        expect(subject.IsHostLocal(host)).to eq(true)
      end
    end

    it "returns true when the short hostname is given" do
      expect(subject.IsHostLocal(hostname_short)).to eq(true)
    end

    it "returns true when the fq hostname is given" do
      expect(subject.IsHostLocal(hostname_fq)).to eq(true)
    end

    context "for IPv4" do
      let(:ipv4) { true }

      it "returns true when the ip of local machine is given" do
        expect(subject.IsHostLocal(ip)).to eq(true)
      end

      it "returns false when the ip of local machine is not given" do
        expect(subject.IsHostLocal("1.2.3.4")).to eq(false)
      end
    end
  end

  describe ".Read" do
    it "delegates DNS settings reading to Yast::Lan module" do
      expect(Yast::Lan).to receive(:Read).with(:cache)
      subject.Read
    end
  end

  describe ".Write" do
    let(:dns_writer) { instance_double(Y2Network::Sysconfig::DNSWriter) }
    let(:yast_config) { double("Y2Network::Config", dns: instance_double("Y2Network::DNS")) }
    let(:system_config) { double("Y2Network::Config", dns: instance_double("Y2Network::DNS")) }

    before do
      allow(Y2Network::Sysconfig::DNSWriter).to receive(:new).and_return(dns_writer)
      allow(Yast::Lan).to receive(:yast_config).and_return(yast_config)
      allow(Yast::Lan).to receive(:system_config).and_return(system_config)
    end

    it "writes DNS settings" do
      expect(dns_writer).to receive(:write)
        .with(yast_config.dns, system_config.dns, netconfig_update: true)
      subject.Write
    end
  end

  describe ".modified" do
    let(:yast_config) { double("Y2Network::Config", dns: double("dns")) }
    let(:system_config) { double("Y2Network::Config", dns: double("dns")) }

    before do
      allow(Yast::Lan).to receive(:yast_config).and_return(yast_config)
      allow(Yast::Lan).to receive(:system_config).and_return(system_config)
    end

    context "when DNS configuration has changed" do
      it "returns true" do
        expect(subject.modified).to eq(true)
      end
    end

    context "when DNS configuration has not changed" do
      let(:system_config) { double("Y2Network::Config", dns: yast_config.dns) }

      it "returns false" do
        expect(subject.modified).to eq(false)
      end
    end
  end

  describe "#hostname" do
    it "provides static hostname" do
      expect(subject.hostname).to eq "install"
    end
  end

  describe "#hostname=" do
    let(:hostname_config) do
      Y2Network::Hostname.new
    end

    it "sets static hostname" do
      subject.hostname = "test"
      expect(subject.hostname).to eq "test"
    end
  end
end
