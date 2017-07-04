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

      context "The AutoYaST first stage installation" do
        let(:settings) { { "hostname" => "host", "searchlist" => ["example.com"] } }

        before do
          allow(Yast::Stage).to receive(:initial).and_return(true)
          allow(Yast::Mode).to receive(:auto).and_return(true)
          allow(Yast).to receive(:import).with("AutoinstConfig")
          # reset the internal counter
          DNS.instance_variable_set(:@error_reported, false)
        end

        it "prints a warning when the 2nd stage is disabled for writing the search list" do
          stub_const("Yast::AutoinstConfig", double(second_stage: false))
          expect(Yast::Report).to receive(:Warning)
          DNS.Import(settings)
        end

        it "prints the warning only once on multiple calls" do
          stub_const("Yast::AutoinstConfig", double(second_stage: false))
          expect(Yast::Report).to receive(:Warning).once
          DNS.Import(settings)
          DNS.Import(settings)
        end

        it "does not print a warning when the 2nd stage is enabled for writing the search list" do
          stub_const("Yast::AutoinstConfig", double(second_stage: true))
          expect(Yast::Report).to_not receive(:Warning)
          DNS.Import(settings)
        end
      end
    end
  end
end
