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

require_relative "../../test_helper"
require "y2network/autoinst_profile/interfaces_section"
require "y2network/autoinst/interfaces_reader"
require "y2network/interface"

describe Y2Network::Autoinst::InterfacesReader do
  let(:subject) { described_class.new(interfaces_section) }
  let(:interfaces_section) do
    Y2Network::AutoinstProfile::InterfacesSection.new_from_hashes(interfaces_profile)
  end

  let(:eth1) do
    {
      "startmode"             => "auto",
      "bootproto"             => "static",
      "device"                => "eth1",
      "name"                  => "",
      "ipaddr"                => "192.168.10.10",
      "dhclient_set_hostname" => "no",
      "netmask"               => "255.255.255.0"
    }
  end

  let(:eth0) do
    {
      "bootproto"             => "dhcp",
      "name"                  => "eth0",
      "description"           => "Ethernet Card 0",
      "startmode"             => "boot",
      "dhclient_set_hostname" => "yes",
      "lladdr"                => "02:0b:0c:0d:0e:02",
      "aliases"               => {
        "alias0" => {
          "IPADDR"    => "10.100.0.1",
          "PREFIXLEN" => "24",
          "LABEL"     => "test"
        },
        "alias1" => {
          "IPADDR"    => "10.100.0.2",
          "PREFIXLEN" => "/24",
          "LABEL"     => "test2"
        },
        "alias2" => {
          "IPADDR"  => "10.100.0.3",
          "NETMASK" => "255.255.0.0",
          "LABEL"   => "TEST3"
        }
      }
    }
  end

  let(:interfaces_profile) { [eth1, eth0] }

  describe "#config" do
    let(:i_list) { double("IssuesList", add: nil) }
    let(:missing_value) { ::Installation::AutoinstIssues::MissingValue }
    let(:invalid_value) { ::Installation::AutoinstIssues::InvalidValue }

    before do
      allow(Yast::AutoInstall).to receive(:issues_list).and_return(i_list)
    end

    it "builds a new Y2Network::ConnectionConfigsCollection" do
      expect(subject.config).to be_a Y2Network::ConnectionConfigsCollection
      expect(subject.config.size).to eq(2)
    end

    it "assign properly all values in profile" do
      eth0_config = subject.config.by_name("eth0")
      expect(eth0_config.startmode.name).to eq("auto")
      expect(eth0_config.description).to eq("Ethernet Card 0")
      expect(eth0_config.startmode.alias_name).to eq("boot")
      expect(eth0_config.bootproto).to eq Y2Network::BootProtocol.from_name("dhcp")
      expect(eth0_config.ip_aliases.size).to eq 3
      expect(eth0_config.dhclient_set_hostname).to eq true
      expect(eth0_config.lladdress).to eq("02:0b:0c:0d:0e:02")
      eth1_config = subject.config.by_name("eth1")
      expect(eth1_config.name).to eq("eth1")
      expect(eth1_config.ip.address.prefix).to eql(24)
      expect(eth1_config.ip.address.to_s).to eq("192.168.10.10/24")
      expect(eth1_config.dhclient_set_hostname).to eq false
    end

    context "when reading an interface section" do
      context "which does not provide an interface or device name" do
        before do
          eth1["device"] = ""
        end

        it "skips the connection configuration for that interface section" do
          expect(subject.config.size).to eq(1)
        end

        it "adds an missing value issue to the AutoInstall issues list" do
          eth1_section = interfaces_section.interfaces[0]
          expect(i_list).to receive(:add)
            .with(missing_value, eth1_section, :name, "The section will be skipped")
          subject.config
        end
      end

      context "which does not provide a bootproto attr" do
        before do
          eth1["bootproto"] = ""
        end

        it "adds an missing value issue to the AutoInstall issues list" do
          eth1_section = interfaces_section.interfaces[0]
          expect(i_list).to receive(:add).with(missing_value, eth1_section, :bootproto)
          subject.config
        end
      end

      context "which provides a wrong bootproto attr" do
        let(:default) { Y2Network::BootProtocol.from_name("static") }

        before do
          eth1["bootproto"] = "dchp"
        end

        it "does not touch the bootproto keeping the default connection config value" do
          eth1_config = subject.config.by_name("eth1")
          expect(eth1_config.bootproto).to eql(default)
        end

        it "adds an invalid value issue to the AutoInstall issues list" do
          eth1_section = interfaces_section.interfaces[0]
          expect(i_list).to receive(:add)
            .with(invalid_value, eth1_section, :bootproto, "dchp", "replaced by 'static'")
          subject.config
        end
      end

      context "which provides a wrong startmode attr" do
        before do
          eth1["startmode"] = "auo"
        end

        it "does not touch the bootproto keeping the default connection config value" do
          eth1_config = subject.config.by_name("eth1")
          expect(eth1_config.startmode).to be_a(Y2Network::Startmode)
        end

        it "adds an invalid value issue to the AutoInstall issues list" do
          eth1_section = interfaces_section.interfaces[0]
          expect(subject).to receive(:add_invalid_issue).with(eth1_section, :startmode, anything)
          subject.config
        end
      end

      context "and it provides an static IP configuration" do
        context "but does not provide an ipaddr" do
          before do
            eth1["ipaddr"] = ""
          end

          it "does not set any IPConfig at all" do
            eth1_config = subject.config.by_name("eth1")
            expect(eth1_config.ip).to eql(nil)
          end
        end

        context "and provides a netmask in prefix length format" do
          before { eth1["netmask"] = "16" }

          it "initializes correctly the IPConfig" do
            eth1_config = subject.config.by_name("eth1")
            expect(eth1_config.ip.address.to_s).to eql("192.168.10.10/16")
          end
        end
      end

      context "which defines a set of IP aliases" do
        it "initializes the IPConfig objects for each of those aliases correctly" do
          eth0_config = subject.config.by_name("eth0")
          expect(eth0_config.ip_aliases.size).to eq(3)
          expect(eth0_config.ip_aliases.map(&:id)).to eql(["_0", "_1", "_2"])
          alias1 = eth0_config.ip_aliases.find { |a| a.id == "_1" }
          expect(alias1.address.to_s).to eql("10.100.0.2/24")
          expect(alias1.label).to eql("test2")
          alias2 = eth0_config.ip_aliases.find { |a| a.label == "TEST3" }
          expect(alias2.address.to_s).to eql("10.100.0.3/16")
        end

        context "and some of the aliases do not provide an IPADDR" do
          before do
            eth0["aliases"]["alias1"].delete("IPADDR")
          end

          it "skips those aliases with no IPADDR" do
            eth0_config = subject.config.by_name("eth0")
            expect(eth0_config.ip_aliases.size).to eq(2)
            expect(eth0_config.ip_aliases.map(&:id)).to eql(["_0", "_2"])
          end
        end
      end
    end
  end
end
