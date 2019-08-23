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

module Yast
  import "Arch"
  import "DNS"
  import "ProductControl"
  import "Lan"

  describe DNS do
    let(:lan_config) do
      Y2Network::Config.new(dns: dns_config, source: :sysconfig)
    end
    let(:dns_config) do
      Y2Network::DNS.new(dhcp_hostname: true)
    end

    before do
      allow(Lan).to receive(:yast_config).and_return(lan_config)
    end

    describe ".default_dhcp_hostname" do
      before do
        allow(Arch).to receive(:is_laptop).and_return laptop
        ProductControl.ReadControlFile(File.join(SCRStub::DATA_PATH, control_file))
      end

      context "with dhcp_hostname=true in control file" do
        let(:control_file) { "dhcp_hostname_true.xml" }

        context "in a laptop" do
          let(:laptop) { true }

          it "returns the value from product features" do
            expect(DNS.default_dhcp_hostname).to eql(true)
          end
        end

        context "in a workstation" do
          let(:laptop) { false }

          it "returns the value from product features" do
            expect(DNS.default_dhcp_hostname).to eql(true)
          end
        end
      end

      context "with dhcp_hostname=false in control file" do
        let(:control_file) { "dhcp_hostname_false.xml" }

        context "in a laptop" do
          let(:laptop) { true }

          it "returns the value from product features" do
            expect(DNS.default_dhcp_hostname).to eql(false)
          end
        end

        context "in a workstation" do
          let(:laptop) { false }

          it "returns the value from product features" do
            expect(DNS.default_dhcp_hostname).to eql(false)
          end
        end
      end

      context "without dhcp_hostname in control file" do
        let(:control_file) { "dhcp_hostname_nil.xml" }

        context "in a laptop" do
          let(:laptop) { true }

          it "returns false" do
            expect(DNS.default_dhcp_hostname).to eql(false)
          end
        end

        context "in a workstation" do
          let(:laptop) { false }

          it "returns true" do
            expect(DNS.default_dhcp_hostname).to eql(true)
          end
        end
      end
    end

    describe ".IsHostLocal" do
      let(:ip) { "10.111.66.75" }
      let(:hostname_short) { "test" }
      let(:hostname_fq) { "test.test.de" }
      let(:output) { { "ip" => ip, "hostname_short" => hostname_short, "hostname_fq" => hostname_fq } }
      let(:ipv4) { false }
      let(:ipv6) { false }
      let(:stdout) { double }

      before do
        DNS.dhcp_hostname = true

        allow(DNS).to receive(:Read)
        allow(IP).to receive(:Check4).and_return(ipv4)
        allow(IP).to receive(:Check6).and_return(ipv6)
        allow(Yast::Execute).to receive(:stdout).and_return(stdout)
        allow(stdout).to receive(:on_target!).with("/bin/hostname -i").and_return(ip)
        allow(stdout).to receive(:on_target!).with("/bin/hostname").and_return(hostname_short)
        allow(stdout).to receive(:on_target!).with("/bin/hostname -f").and_return(hostname_fq)
      end

      ["localhost", "localhost.localdomain", "::1", "127.0.0.1"].each do |host|
        it "returns true when host is \"#{host}\"" do
          expect(DNS.IsHostLocal(host)).to eq(true)
        end
      end

      it "returns true when the short hostname is given" do
        expect(DNS.IsHostLocal(hostname_short)).to eq(true)
      end

      it "returns true when the fq hostname is given" do
        expect(DNS.IsHostLocal(hostname_fq)).to eq(true)
      end

      context "for IPv4" do
        let(:ipv4) { true }

        it "returns true when the ip of local machine is given" do
          expect(DNS.IsHostLocal(ip)).to eq(true)
        end

        it "returns false when the ip of local machine is not given" do
          expect(DNS.IsHostLocal("1.2.3.4")).to eq(false)
        end
      end
    end

    describe ".Read" do
      it "delegates DNS settings reading to Yast::Lan module" do
        expect(Yast::Lan).to receive(:Read).with(:cache)
        Yast::DNS.Read
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
        expect(dns_writer).to receive(:write).with(yast_config.dns, system_config.dns)
        DNS.Write
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
          expect(DNS.modified).to eq(true)
        end
      end

      context "when DNS configuration has not changed" do
        let(:system_config) { double("Y2Network::Config", dns: yast_config.dns) }

        it "returns false" do
          expect(DNS.modified).to eq(false)
        end
      end
    end

    describe "#propose_hostname" do
      it "proposes a hostname" do
        expect(dns_config).to receive(:ensure_hostname!)
        DNS.propose_hostname
      end
    end
  end
end
