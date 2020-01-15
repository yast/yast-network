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

require "network/clients/inst_setup_dhcp"

describe Yast::SetupDhcp do
  subject { Yast::SetupDhcp.instance }

  let(:lan_config) do
    double("lan_config").as_null_object
  end
  let(:wicked_in_use) { true }

  before do
    allow(Yast::Lan).to receive(:Read).and_return(lan_config)
    allow(Yast::Lan).to receive(:yast_config).and_return(lan_config)
  end

  describe "#main" do
    let(:nac) { Yast::NetworkAutoconfiguration.instance }
    before do
      allow(Yast::NetworkService).to receive(:Read)
      allow(Yast::NetworkService).to receive(:wicked?).and_return(wicked_in_use)
    end

    context "when wicked is not in use" do
      let(:wicked_in_use) { false }

      it "does not try to autoconfigure the network" do
        expect(nac).to_not receive(:any_iface_active?)

        subject.main
      end

      it "returns :next" do
        expect(subject.main).to eql :next
      end
    end

    context "when wicked is in use" do
      it "returns :next when autoconfiguration is not performed" do
        allow(nac)
          .to receive(:any_iface_active?)
          .and_return(true)

        expect(subject.main).to eql :next
      end

      it "returns :next when autoconfiguration is performed" do
        allow(nac)
          .to receive(:any_iface_active?)
          .and_return(false)
        allow(nac)
          .to receive(:configure_dhcp)
          .and_return(true)

        expect(subject.main).to eql :next
      end

      it "runs network dhcp autoconfiguration if no active interfaces" do
        allow(nac)
          .to receive(:any_iface_active?)
          .and_return(false)

        expect(nac)
          .to receive(:configure_dhcp)

        subject.main
      end
    end

    context "in the initial Stage" do
      context "and wicked in use" do
        it "writes DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp" do
          allow(nac)
            .to receive(:any_iface_active?)
            .and_return(true)

          expect(Yast::Stage).to receive(:initial).and_return(true)
          expect(subject).to receive(:set_dhcp_hostname!)

          subject.main
        end
      end
    end
  end

  describe "#set_dhcp_hostname!" do
    let(:dhclient_set_hostname_path) do
      Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME")
    end

    before do
      allow(Yast::SCR).to receive(:Write)
    end

    context "when the linurc sethostname option has been used" do
      before do
        allow(subject).to receive(:set_hostname_used?).and_return(true)
      end

      it "sets DNS.dhcp_hostname according to the linuxrc sethosname value" do
        expect(subject).to receive(:set_dhcp_hostname?).and_return(false)
        expect(Yast::DNS).to receive(:dhcp_hostname=).with(:none)

        subject.set_dhcp_hostname!
      end
    end

    context "when the linurc sethostname option has not been used" do
      before do
        allow(subject).to receive(:set_hostname_used?).and_return(false)
      end

      context "and the DNS.default_dhcp_hostname is true" do
        it "sets the DNS.dhcp_hostname to :any" do
          expect(subject).to_not receive(:set_dhcp_hostname?)
          expect(Yast::DNS).to receive(:default_dhcp_hostname).and_return(true)
          expect(Yast::DNS).to receive(:dhcp_hostname=).with(:any)
          subject.set_dhcp_hostname!
        end
      end

      context "and the DNS.default_dhcp_hostname is false" do
        it "sets the DNS.dhcp_hostname to :none" do
          expect(subject).to_not receive(:set_dhcp_hostname?)
          expect(Yast::DNS).to receive(:default_dhcp_hostname).and_return(false)
          expect(Yast::DNS).to receive(:dhcp_hostname=).with(:none)
          subject.set_dhcp_hostname!
        end
      end
    end

    context "once initialized DNS.dhcp_hostname" do
      context "when it is :any" do
        it "writes global DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp as 'yes'" do
          allow(Yast::DNS).to receive(:dhcp_hostname=)
          allow(Yast::DNS).to receive(:dhcp_hostname).and_return(:any)
          expect(Yast::SCR).to receive(:Write).with(dhclient_set_hostname_path, "yes")

          subject.set_dhcp_hostname!
        end
      end

      context "when it is :none" do
        it "writes global DHCLIENT_SET_HOSTNAME in /etc/sysconfig/network/dhcp as 'no'" do
          allow(Yast::DNS).to receive(:dhcp_hostname=)
          allow(Yast::DNS).to receive(:dhcp_hostname).and_return(:none)
          expect(Yast::SCR).to receive(:Write).with(dhclient_set_hostname_path, "no")

          subject.set_dhcp_hostname!
        end
      end
    end
  end

  describe "set_dhcp_hostname?" do
    before do
      allow(Yast::Linuxrc).to receive(:InstallInf)
        .with("SetHostname").and_return(set_hostname)
    end

    context "when dhcp hostname has not been disabled by linuxrc" do
      let(:set_hostname) { "1" }

      it "returns true" do
        expect(subject.set_dhcp_hostname?).to eql(true)
      end
    end

    context "when dhcp hostname has been disabled by linuxrc" do
      let(:set_hostname) { "0" }

      it "returns false" do
        expect(subject.set_dhcp_hostname?).to eql(false)
      end
    end
  end
end
