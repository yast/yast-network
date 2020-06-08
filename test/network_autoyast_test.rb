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

require "network/network_autoyast"
require "y2network/sysconfig/config_reader"
require "y2network/s390_device_activators/qeth"

Yast.import "Profile"
Yast.import "Lan"

describe "NetworkAutoYast" do
  subject(:network_autoyast) { Yast::NetworkAutoYast.instance }
  let(:config) do
    Y2Network::Config.new(
      interfaces: Y2Network::InterfacesCollection.new([]),
      routing:    Y2Network::Routing.new(tables: []),
      dns:        Y2Network::DNS.new,
      source:     :sysconfig
    )
  end

  before do
    allow(Yast::NetworkInterfaces).to receive(:adapt_old_config!)
    allow(Y2Network::Config).to receive(:from).and_return(double("config").as_null_object)
    allow(Yast::Lan).to receive(:Read)
    Yast::Lan.add_config(:yast, config)
  end

  describe "#merge_dns" do
    let(:instsys_dns_setup) do
      {
        "hostname"           => "instsys_hostname",
        "domain"             => "instsys_domain",
        "nameservers"        => [],
        "searchlist"         => [],
        "dhcp_hostname"      => false,
        "resolv_conf_policy" => "instsys_resolv_conf_policy",
        "write_hostname"     => false
      }
    end
    let(:ay_dns_setup) do
      {
        "hostname"           => "ay_hostname",
        "domain"             => "ay_domain",
        "nameservers"        => [],
        "searchlist"         => [],
        "dhcp_hostname"      => true,
        "resolv_conf_policy" => "ay_resolv_conf_policy"
      }
    end

    it "uses values from instsys, when nothing else is defined" do
      result = network_autoyast.send(:merge_dns, instsys_dns_setup, {})

      instsys_dns_setup.delete("write_hostname")
      expect(result).to eql instsys_dns_setup
    end

    it "ignores instsys values, when AY provides ones" do
      result = network_autoyast.send(:merge_dns, instsys_dns_setup, ay_dns_setup)

      expect(result).to eql ay_dns_setup
    end
  end

  describe "#merge_routing" do
    let(:instsys_routing_setup) do
      {
        "routes"       => ["array of instsys routes"],
        "ipv4_forward" => false,
        "ipv6_forward" => false
      }
    end
    let(:ay_routing_setup) do
      {
        "routes"       => ["array of AY routes"],
        "ipv4_forward" => true,
        "ipv6_forward" => true
      }
    end

    it "uses values from instsys, when nothing else is defined" do
      result = network_autoyast.send(:merge_routing, instsys_routing_setup, {})

      expect(result).to eql instsys_routing_setup
    end

    it "ignores instsys values, when AY provides ones" do
      result = network_autoyast.send(:merge_routing, instsys_routing_setup, ay_routing_setup)

      expect(result).to eql ay_routing_setup
    end
  end

  describe "#merge_configs" do
    it "merges all necessary stuff" do
      stub_const("Yast::UI", double.as_null_object)
      expect(network_autoyast).to receive(:merge_dns)
      expect(network_autoyast).to receive(:merge_routing)

      network_autoyast.merge_configs("dns" => {}, "routing" => {}, "interfaces" => [])
    end
  end

  describe "#set_network_service" do
    Yast.import "NetworkService"
    Yast.import "Mode"

    let(:network_autoyast) { Yast::NetworkAutoYast.instance }

    before(:each) do
      allow(Yast::Mode).to receive(:autoinst).and_return(true)
    end

    def product_use_nm(nm_used)
      allow(Yast::ProductFeatures)
        .to receive(:GetStringFeature)
        .with("network", "network_manager")
        .and_return nm_used
    end

    def networking_section(net_section)
      allow(network_autoyast).to receive(:ay_networking_section).and_return(net_section)
    end

    def nm_installed(installed)
      allow(Yast::Package)
        .to receive(:Installed)
        .and_return installed
    end

    context "in SLED product" do
      before(:each) do
        product_use_nm("always")
        nm_installed(true)
        networking_section("managed" => true)
      end

      it "enables NetworkManager" do
        expect(Yast::NetworkService)
          .to receive(:is_backend_available)
          .with(:network_manager)
          .and_return true
        expect(Yast::NetworkService).to receive(:use_network_manager).and_return nil
        expect(Yast::NetworkService).to receive(:EnableDisableNow).and_return nil

        network_autoyast.set_network_service
      end
    end

    context "in SLES product" do
      before(:each) do
        product_use_nm("never")
        nm_installed(false)
        networking_section({})
      end

      it "enables wicked" do
        expect(Yast::NetworkService).to receive(:use_wicked).and_return nil
        expect(Yast::NetworkService).to receive(:EnableDisableNow).and_return nil

        network_autoyast.set_network_service
      end
    end
  end

  describe "#keep_net_config?" do
    let(:network_autoyast) { Yast::NetworkAutoYast.instance }
    let(:profile) { { "networking" => { "keep_install_network" => true } } }

    before do
      Yast::Lan.Import(Yast::Lan.FromAY(profile["networking"]))
      allow(Yast::Profile).to receive(:current).and_return(profile)
    end

    context "when keep_install_network is true in AY profile" do
      it "returns true" do
        expect(network_autoyast.keep_net_config?).to be true
      end
    end

    context "when keep_install_network is false in AY profile" do
      let(:profile) { { "networking" => { "keep_install_network" => false } } }
      it "returns false" do
        expect(network_autoyast.keep_net_config?).to be false
      end
    end

    context "when keep_install_network is not present in AY profile" do
      let(:profile) { { "networking" => { "setup_before_proposal" => true } } }

      it "returns true" do
        expect(network_autoyast.keep_net_config?).to be true
      end
    end
  end

  describe "#configure_lan" do
    before do
      Yast::Lan.autoinst = nil
      allow(Yast::Profile).to receive(:current)
        .and_return("general" => general_section, "networking" => networking_section)
      allow(Yast::AutoInstall).to receive(:valid_imported_values).and_return(true)
      allow(Yast::Lan).to receive(:Write)
      Yast::Lan.autoinst.before_proposal = before_proposal
    end

    let(:networking_section) { nil }
    let(:general_section) { nil }
    let(:before_proposal) { false }

    context "when second stage is explicitly enabled" do
      let(:general_section) do
        { "mode" => { "second_stage" => true } }
      end

      it "does not write the Lan module configuration" do
        expect(Yast::Lan).to_not receive(:Write)
        subject.configure_lan
      end

      it "returns false" do
        expect(subject.configure_lan).to eql(false)
      end
    end

    context "when the configuration was written before the proposal" do
      let(:before_proposal) { true }
      let(:networking_section) { { "setup_before_proposal" => before_proposal } }

      it "does not write anything" do
        expect(Yast::Lan).to_not receive(:Write)
        expect(subject.configure_lan).to eql(false)
      end

      it "returns false" do
        expect(subject.configure_lan).to eql(false)
      end
    end

    context "when the second stage is disabled" do
      let(:before_proposal) { true }
      let(:networking_section) { { "setup_before_proposal" => before_proposal } }
      let(:general_section) do
        { "mode" => { "second_stage" => false } }
      end

      context "and the configuration was not written before the proposal" do
        let(:before_proposal) { false }

        context "if the user wants to keep the installation network" do
          let(:networking_section) do
            { "keep_install_network" => true, "setup_before_proposal" => before_proposal }
          end

          it "merges the installation configuration" do
            expect(Yast::NetworkAutoYast.instance).to receive(:merge_configs)
            subject.configure_lan
          end
        end

        context "if the user does not want to keep the installation network" do
          let(:networking_section) do
            { "keep_install_network" => false, "setup_before_proposal" => before_proposal }
          end

          it "does not merge the installation configuration" do
            expect(Yast::NetworkAutoYast.instance).to_not receive(:merge_configs)
            subject.configure_lan
          end
        end

        it "writes the Lan module configuration" do
          expect(Yast::Lan).to receive(:Write)
          subject.configure_lan
        end
      end

      context "and the configuration was written before the proposal" do
        it "does not write anything" do
          expect(Yast::Lan).to_not receive(:Write)

          subject.configure_lan
        end

        it "returns false" do
          expect(subject.configure_lan).to eql(false)
        end
      end
    end
  end

  describe "#activate_s390_devices" do
    let(:section) do
      [
        {
          "chanids" => "0.0.0800 0.0.0801 0.0.0802",
          "type"    => "qeth"
        }
      ]
    end

    let(:activator) do
      instance_double(
        Y2Network::S390DeviceActivators::Qeth,
        configured_interface: configured_interface
      )
    end

    let(:configured_interface) { "" }

    before do
      allow(Y2Network::S390DeviceActivators::Qeth).to receive(:new)
        .and_return(activator)
    end

    it "activates the given device" do
      expect(activator).to receive(:configure)
      subject.activate_s390_devices(section)
    end

    context "if the device is already active" do
      let(:configured_interface) { "eth0" }

      it "does not activate the device" do
        expect(activator).to_not receive(:configure)
        subject.activate_s390_devices(section)
      end
    end

    context "if the activation fails" do
      before do
        allow(activator).to receive(:configure).and_raise(RuntimeError)
      end

      it "logs the error" do
        expect(subject.log).to receive(:error).at_least(1)
        subject.activate_s390_devices(section)
      end
    end
  end
end
