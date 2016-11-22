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

    describe "#valid_dhcp_cfg?" do
      def mock_dhcp_setup(ifaces, global)
        allow(LanItems)
          .to receive(:find_set_hostname_ifaces)
          .and_return(ifaces)
        allow(DNS)
          .to receive(:dhcp_hostname)
          .and_return(global)
      end

      it "fails when DHCLIENT_SET_HOSTNAME is set for multiple ifaces" do
        mock_dhcp_setup(["eth0", "eth1"], false)

        expect(DNS.valid_dhcp_cfg?).to be false
      end

      it "fails when DHCLIENT_SET_HOSTNAME is set globaly even in an ifcfg" do
        mock_dhcp_setup(["eth0"], true)

        expect(DNS.valid_dhcp_cfg?).to be false
      end

      it "succeedes when DHCLIENT_SET_HOSTNAME is set for one iface" do
        mock_dhcp_setup(["eth0"], false)

        expect(DNS.valid_dhcp_cfg?).to be true
      end

      it "succeededs when only global DHCLIENT_SET_HOSTNAME is set" do
        mock_dhcp_setup([], true)

        expect(DNS.valid_dhcp_cfg?).to be true
      end
    end
  end
end
