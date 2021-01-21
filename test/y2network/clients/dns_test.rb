#!/usr/bin/env rspec
# Copyright (c) [2020] SUSE LLC
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

require_relative "../../test_helper"
require "y2network/clients/dns"
require "y2network/dns"

describe Y2Network::Clients::DNS do
  let(:args) { [] }

  let(:table) { Y2Network::RoutingTable.new([route]) }
  let(:config) do
    Y2Network::Config.new(interfaces: [], dns: dns, hostname: hostname, source: :wicked)
  end
  let(:dns) { Y2Network::DNS.new(resolv_conf_policy: "auto") }
  let(:hostname) do
    Y2Network::Hostname.new(static: "test", transient: "transient", dhcp_hostname: :any)
  end

  before do
    allow(Yast::WFM).to receive(:Args).and_return(args)
    allow(subject).to receive(:write_config).and_return(true)
    allow(subject).to receive(:read_config).and_return(true)
    allow(subject).to receive(:config).and_return(config)
    allow(Yast::Lan).to receive(:Read)
    allow(Yast::CommandLine).to receive(:Print)
  end

  describe "#main" do
    before do
      allow(subject).to receive(:DNSMainDialog).and_return(:abort)
    end

    it "runs the dns cmdline client" do
      expect(subject).to receive(:cmdline_definition)
      subject.main
    end

    context "when calling with no ARGS" do
      it "reads the current config" do
        expect(subject).to receive(:read_config)
        subject.main
      end

      it "runs the GUI dialog" do
        expect(subject).to receive(:DNSMainDialog).and_return(:abort)
        subject.main
      end

      context "and returned from the dns dialog without changes" do
        it "does not write anything" do
          allow(subject).to receive(:DNSMainDialog).and_return(:next)
          allow(subject).to receive(:modified?).and_return(false)

          expect(subject).to_not receive(:write_config)
          subject.main
        end
      end

      context "and applied some modification in the dns dialog" do
        before do
          allow(subject).to receive(:modified?).and_return(true)
          allow(subject).to receive(:DNSMainDialog).and_return(:next)
          allow(Yast::NetworkService).to receive(:StartStop)
        end

        it "writes the changes" do
          allow(subject).to receive(:write_config).and_call_original
          expect(Yast::Lan).to receive(:write_config).with(only: [:dns, :hostname, :connections])
          subject.main
        end

        it "restarts the network service" do
          expect(Yast::NetworkService).to receive(:StartStop)
          subject.main
        end
      end
    end

    context "when calling with 'list'" do
      let(:args) { ["list"] }

      before do
        allow(subject).to receive(:InitHandler).and_return(true)
        allow(subject).to receive(:FinishHandler).and_return(true)
      end

      it "prints the DNS and hostname summary" do
        expect(Yast::CommandLine).to receive(:Print).with(/DNS Configuration Summary/)
        subject.main
      end
    end

    context "when calling with 'edit'" do
      let(:network_manager) { true }

      before do
        allow(subject).to receive(:read_config).and_return(true)
        allow(subject).to receive(:write_config).and_return(true)
        allow(Yast::NetworkService).to receive(:is_network_manager).and_return(network_manager)
        Yast::Lan.clear_configs
        Yast::Lan.add_config(:system, config.copy)
        Yast::Lan.add_config(:yast, config)
      end

      context "and the hostname is modified" do
        let(:args) { ["edit", "hostname=changedhostname"] }

        it "modifies the static hostname" do
          expect { subject.main }
            .to change { config.hostname.static }
            .from("test").to("changedhostname")
        end
      end

      context "and the network backend is NetworkManager" do
        let(:args) { ["edit", "nameserver1=named1.suse.com"] }

        context "when the options to edit are some of the nameservers" do
          it "prints that the options cannot be set because is managed by Networkmanager" do
            expect(Yast::CommandLine).to receive(:Print).with(/Cannot set nameserver1/)

            subject.main
          end
        end
      end

      context "and the network backend is wicked" do
        let(:args) { ["edit", "nameserver1=8.8.8.8"] }
        let(:network_manager) { false }

        context "when some of the options to edit are some of the nameservers" do
          it "sets them" do
            expect { subject.main }
              .to change { config.dns.nameservers.map(&:to_s) }
              .from([]).to(["8.8.8.8"])
          end
        end
      end
    end
  end
end
