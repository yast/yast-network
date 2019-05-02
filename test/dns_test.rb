#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

module Yast
  import "Arch"
  import "DNS"
  import "ProductControl"

  describe DNS do
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

    describe ".Import" do
      before do
        allow(Yast::Stage).to receive(:initial).and_return(false)
      end

      context "with present dhcp_hostname and write_hostname" do
        let(:settings) { { "hostname" => "host", "dhcp_hostname" => true, "write_hostname" => true } }

        it "honors the provided values" do
          expect(DNS).to_not receive(:DefaultWriteHostname)
          expect(DNS).to_not receive(:default_dhcp_hostname)
          DNS.Import(settings)
          expect(DNS.write_hostname).to eql(true)
          expect(DNS.dhcp_hostname).to eql(true)
        end
      end

      context "with missing dhcp_hostname and write_hostname" do
        let(:settings) { { "hostname" => "host" } }

        it "relies on proper methods to get default values" do
          expect(DNS).to receive(:DefaultWriteHostname).and_return false
          expect(DNS).to receive(:default_dhcp_hostname).and_return false
          DNS.Import(settings)
          expect(DNS.write_hostname).to eql(false)
          expect(DNS.dhcp_hostname).to eql(false)
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
      let(:dns_writer) { instance_double(Y2Network::ConfigWriter::SysconfigDNS) }
      let(:yast_config) { double("Y2Network::Config") }
      let(:system_config) { double("Y2Network::Config") }

      before do
        allow(Y2Network::ConfigWriter::SysconfigDNS).to receive(:new).and_return(dns_writer)
        allow(Yast::Lan).to receive(:yast_config).and_return(yast_config)
        allow(Yast::Lan).to receive(:system_config).and_return(system_config)
      end

      it "writes DNS settings" do
        expect(dns_writer).to receive(:write).with(yast_config, system_config)
        DNS.Write
      end
    end
  end
end
