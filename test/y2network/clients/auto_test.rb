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
require "y2network/clients/auto"

describe Y2Network::Clients::Auto do
  let(:static_ip) { "1.2.3.4" }

  let(:network_autoyast) { Yast::NetworkAutoYast.instance }
  let(:eth0) { { "device" => "eth0", "bootproto" => "dhcp", "startmode" => "auto" } }
  let(:eth1) { { "device" => "eth1", "bootproto" => "static", "ipaddr" => static_ip } }
  let(:interfaces) { [eth0] }

  let(:dns) { { "hostname" => "host", "dhcp_hostname" => true, "write_hostname" => true } }
  let(:routes) do
    [
      {
        "destination" => "default",
        "gateway"     => "192.168.1.1",
        "netmask"     => "255.255.255.0",
        "device"      => "-"
      },
      {
        "destination" => "172.26.0.0/24",
        "device"      => "eth0"
      }
    ]
  end

  let(:profile) do
    {
      "keep_install_network" => false,
      "interfaces"           => interfaces,
      "routing"              => {
        "ipv4_forward" => true,
        "ipv6_forward" => false,
        "routes"       => routes
      },
      "dns"                  => dns
    }
  end

  describe "#reset" do
    it "clears Yast::Lan internal state" do
      allow(Yast::Lan).to receive(:Import).with({})
      expect(Yast::Lan).to receive(:clear_configs)
      subject.reset
    end
  end

  describe "#read" do
    it "forces a Lan read" do
      expect(Yast::Lan).to receive(:Read).with(:nocache)
      subject.read
    end
  end

  describe "#import" do
    let(:profile) { { "keep_install_network" => false } }
    let(:from_ay_profile) { profile.dup }

    before do
      allow(Yast::Lan).to receive(:Import)
      allow(Yast::Lan).to receive(:FromAY).with(profile).and_return(from_ay_profile)
    end

    it "prepares the given profile to be imported" do
      expect(Yast::Lan).to receive(:FromAY).with(profile).and_return(from_ay_profile)

      subject.import(profile)
    end

    it "imports the given profile" do
      expect(Yast::Lan).to receive(:Import).with(from_ay_profile)

      subject.import(profile)
    end

    context "unless the profile specifies that the current config should be ignored" do
      let(:profile) { { "keep_install_network" => true } }

      it "merges the given profile with the current network config before import" do
        expect(network_autoyast).to receive(:merge_configs).with(from_ay_profile)

        subject.import(profile)
      end
    end

    context "when the profile specifies that the current config should be ignored" do
      it "does not merge the given profile with the current network config before import" do
        expect(network_autoyast).to_not receive(:merge_configs)

        subject.import(profile)
      end
    end
  end

  describe "#export" do
    it "exports the current network configuration prepared for AutoYaST" do
      expect(Yast::Lan).to receive(:Export).and_return(:exported_config)
      expect(subject).to receive(:adapt_for_autoyast).with(:exported_config).and_return(:ay_config)
      expect(subject.export).to eql(:ay_config)
    end
  end

  describe "#summary" do
    let(:config_summary) { "config" }

    it "returns a text summary of the autoyast config network configuration" do
      allow(Yast::Lan).to receive(:Summary).with("summary").and_return(config_summary)

      expect(subject.summary).to eql(config_summary)
    end
  end

  describe "#packages" do
    let(:packages) { { "install" => ["wpa_supplicant"], "remove" => [] } }

    it "returns a hash with the packages that need to be installed and removed" do
      allow(Yast::Lan).to receive(:AutoPackages).and_return(packages)
      expect(subject.packages).to eql(packages)
    end
  end

  describe "#modified" do
    it "sets the network config as modified" do
      subject.class.modified = false
      expect { subject.modified }.to change { subject.modified? }.from(false).to(true)
    end
  end

  describe "#modified?" do
    it "returns whether modified is called or not" do
      subject.modified
      expect(subject.modified?).to eq true
    end
  end

  describe "#write" do
    let(:system_config) { Y2Network::Config.new(source: :wicked) }

    before do
      allow(Yast::Lan).to receive(:Read)
      Y2Network::Config.add(:system, system_config)
      allow(Yast::Lan).to receive(:WriteOnly)
      subject.import(profile)
    end

    it "writes the imported network configuration" do
      expect(Yast::Lan).to receive(:WriteOnly)

      subject.write
    end

    context "when the imported profile declares a strict ip check timeout" do
      let(:profile) do
        {
          "strict_IP_check_timeout" => 15
        }
      end

      context "and some interfaces is down" do
        before do
          allow(Yast::Lan).to receive(:isAnyInterfaceDown).and_return(true)
        end

        it "shows an error popup with the given timeout" do
          expect(Yast::Popup).to receive(:TimedError)

          subject.write
        end
      end
    end
  end

  describe "#update_etc_hosts" do
    let(:system_config) { Y2Network::Config.new(source: :sysconfig) }
    let(:yast_config) { Y2Network::Config.find(:yast) }

    before(:each) do
      allow(Yast::Lan).to receive(:Read)
      allow(Yast::Stage).to receive(:cont).and_return(true)
      Y2Network::Config.add(:system, system_config)
    end

    it "updates /etc/hosts with a record for each static ip" do
      extended_profile = profile
      extended_profile["interfaces"] = interfaces + [eth1]

      subject.import(extended_profile)

      connection = yast_config.connections.find { |c| c.static? && c.ip.address == static_ip }

      expect(connection.hostname).to eql dns["hostname"]
    end

    it "doesn't do anything in case of missing static ips" do
      expect(Yast::Host).not_to receive(:Update)

      subject.import(profile)
    end
  end
end
