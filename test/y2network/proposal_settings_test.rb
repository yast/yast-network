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

require_relative "../test_helper"
require "y2network/proposal_settings"

describe Y2Network::ProposalSettings do
  subject { described_class.create_instance }
  let(:nm_available) { true }
  let(:feature) { { "network" => { "network_manager" => "always" } } }

  before do
    allow_any_instance_of(Y2Network::ProposalSettings)
      .to receive(:network_manager_available?).and_return(nm_available)
    stub_features(feature)
  end

  def stub_features(features)
    Yast.import "ProductFeatures"
    Yast::ProductFeatures.Import(features)
    # Prevent to Restore or Init
    allow(Yast::ProductFeatures).to receive(:InitIfNeeded)
  end

  describe ".instance" do
    context "no instance has been created yet" do
      before do
        described_class.instance_variable_set("@instance", nil)
      end

      it "creates a new instance" do
        expect(described_class).to receive(:new).and_call_original
        described_class.instance
      end
    end

    context "when a instance has been already created" do
      before do
        described_class.instance
      end

      it "does not create any new instance" do
        expect(described_class).to_not receive(:new)
        described_class.instance
      end

      it "returns the existent instance" do
        instance = described_class.instance
        expect(instance.object_id).to eql(described_class.instance.object_id)
      end
    end
  end

  describe ".create_instance" do
    let(:created_instance) { described_class.create_instance }
    let(:nm_available) { false }
    let(:managed) { nil }

    before do
      allow(Yast::Lan.autoinst).to receive(:managed).and_return(managed)
    end

    it "creates a new network proposal settings instance" do
      instance = described_class.instance
      expect(created_instance).to be_a(described_class)
      expect(created_instance).to_not equal(instance)
    end

    context "when NetworkManager is selected by AutoYaST" do
      let(:managed) { true }

      it "initializes the selected backend" do
        expect(created_instance.selected_backend).to eql(:network_manager)
      end
    end
  end

  describe "#default_backend" do
    let(:subject) { described_class.create_instance }
    let(:logger) { double(info: true) }
    let(:nm_available) { false }

    context "when the NetworkManager package is not available" do
      it "returns :wicked as the default backend" do
        expect(subject.default_backend).to eql(:wicked)
      end
    end

    context "when the NetworkManager package is available" do
      let(:nm_available) { true }

      context "and the ProductFeature .network.network_manager is not defined" do
        context "and neither .network.network_manager_is_default is" do
          let(:feature) { { "network" => {} } }

          it "returns :wicked as the default backend" do
            expect(subject.default_backend).to eql(:wicked)
          end
        end

        context "but .network.network_manager_is_default is" do
          let(:feature) { { "network" => { "network_manager_is_default" => true } } }

          it "returns :network_manager as the default backend" do
            expect(subject.default_backend).to eql(:network_manager)
          end
        end
      end

      context "and the ProductFeature .network.network_manager is 'always'" do
        it "returns :network_manager as the default backend" do
          expect(subject.default_backend).to eql(:network_manager)
        end
      end

      context "and the ProductFeature .network.network_manager is 'laptop'" do
        let(:is_laptop) { true }
        let(:feature) { { "network" => { "network_manager" => "laptop" } } }

        before do
          allow(Yast::Arch).to receive(:is_laptop).and_return(is_laptop)
        end

        context "and the machine is a laptop" do
          it "returns :network_manager as the default backend" do
            expect(subject.default_backend).to eql(:network_manager)
          end
        end

        context "and the machine is not a laptop" do
          let(:is_laptop) { false }
          it "returns :wicked as the default backend" do
            expect(subject.default_backend).to eql(:wicked)
          end
        end
      end

      it "initializes the default network backend from the product control file" do
        expect(subject.default_backend).to eql(:network_manager)
        stub_features(
          "network" => { "network_manager" => "", "network_manager_is_default" => false }
        )
        expect(subject.default_backend).to eql(:wicked)
      end
    end

    it "logs which backend has been selected as the default" do
      allow_any_instance_of(described_class).to receive(:log).and_return(logger)
      expect(logger).to receive(:info).with(/backend is: wicked/)
      subject.default_backend
    end
  end

  describe "#current_backend" do
    let(:selected_backend) { :wicked }
    let(:default_backend) { "wicked_or_nm_based_on_control_file" }

    before do
      allow(subject).to receive(:default_backend).and_return(default_backend)
      subject.selected_backend = selected_backend
    end

    context "when a backend has been selected manually" do
      it "returns the backend selected manually" do
        expect(subject.current_backend).to eql(selected_backend)
      end
    end

    context "when no backend has been selected manually" do
      let(:selected_backend) { nil }

      it "returns the default backend" do
        expect(subject.current_backend).to eql(default_backend)
      end
    end
  end

  describe "#enable_wicked!" do
    it "adds the wicked package to the list of resolvables " do
      expect(Yast::PackagesProposal).to receive(:AddResolvables)
        .with("network", :package, ["wicked"])
      subject.enable_wicked!
    end

    it "removes the NetworkManager package from the list of resolvables " do
      expect(Yast::PackagesProposal).to receive(:RemoveResolvables)
        .with("network", :package, ["NetworkManager"])
      subject.enable_wicked!
    end

    it "sets :wicked as the user selected backend" do
      expect(subject.selected_backend).to be_nil
      subject.enable_wicked!
      expect(subject.selected_backend).to eql(:wicked)
    end
  end

  describe "#refresh_packages" do
    let(:backend) { :wicked }

    before do
      allow(subject).to receive(:current_backend).and_return(backend)
    end

    context "when :wicked is the current backend" do
      it "adds the wicked package to the list of resolvables " do
        expect(Yast::PackagesProposal).to receive(:AddResolvables)
          .with("network", :package, ["wicked"])
        subject.refresh_packages
      end

      it "removes the NetworkManager package from the list of resolvables " do
        expect(Yast::PackagesProposal).to receive(:RemoveResolvables)
          .with("network", :package, ["NetworkManager"])
        subject.refresh_packages
      end
    end

    context "when :network_manager is the current backend" do
      let(:backend) { :network_manager }

      it "adds the NetworkManager package to the list of resolvables " do
        expect(Yast::PackagesProposal).to receive(:AddResolvables)
          .with("network", :package, ["NetworkManager"])
        subject.refresh_packages
      end

      it "removes the wicked package from the list of resolvables " do
        expect(Yast::PackagesProposal).to receive(:RemoveResolvables)
          .with("network", :package, ["wicked"])
        subject.refresh_packages
      end
    end
  end

  describe "#enable_network_manager!" do
    before do
      subject.selected_backend = nil
    end

    it "sets :network_manager as the user selected backend" do
      subject.enable_network_manager!
      expect(subject.selected_backend).to eql(:network_manager)
    end
  end

  describe "#network_manager_available?" do
    let(:package) { instance_double(Y2Packager::Package, status: :available) }
    let(:packages) { [package] }
    let(:settings) { described_class.instance }

    before do
      allow(settings).to receive(:network_manager_available?).and_call_original
      allow(Y2Packager::Package).to receive(:find).with("NetworkManager")
        .and_return(packages)
    end

    context "when there is no NetworkManager package available" do
      let(:packages) { [] }

      it "returns false" do
        expect(settings.network_manager_available?).to eql(false)
      end

      it "logs that the package is no available" do
        expect(settings.log).to receive(:info).with(/is not available/)
        settings.network_manager_available?
      end
    end

    context "when there are some NetworkManager packages available" do
      it "returns true" do
        expect(settings.network_manager_available?).to eql(true)
      end

      it "logs the status of the NetworkManager package" do
        expect(settings.log).to receive(:info).with(/status: available/)
        settings.network_manager_available?
      end
    end
  end

  describe "#network_service" do
    let(:settings) { described_class.instance }
    let(:backend) { :wicked }
    let(:nm_installed) { true }

    before do
      allow(settings).to receive(:current_backend).and_return(backend)
      allow(Yast::Package).to receive(:Installed)
        .with("NetworkManager").and_return(nm_installed)
    end

    context "when the backend selected is wicked" do
      it "returns :wicked" do
        expect(settings.network_service).to eql(:wicked)
      end
    end

    context "when the backend selected is NetworkManager" do
      let(:backend) { :network_manager }

      context "and the NetworkManager package is installed" do
        it "returns :network_manager" do
          expect(settings.network_service).to eql(:network_manager)
        end
      end

      context "and the NetworkManager package is not installed" do
        let(:nm_installed) { false }

        it "returns :wicked" do
          expect(settings.network_service).to eql(:wicked)
        end
      end
    end
  end

  describe "#virtual_proposal_required?" do
    let(:settings) { described_class.instance }
    let(:is_s390) { false }
    let(:installed) { [] }

    before do
      allow(Yast::Arch).to receive(:s390).and_return(is_s390)
      allow(settings).to receive(:package_selected?).and_return(false)
      installed.map do |package|
        allow(settings).to receive(:package_selected?).with(package).and_return(true)
      end
    end

    context "in s390 arch" do
      let(:is_s390) { true }

      it "returns false" do
        expect(settings.virtual_proposal_required?).to eql(false)
      end
    end

    context "when KVM, Xen or QEMU packages are not installed" do
      it "returns false" do
        expect(settings.virtual_proposal_required?).to eql(false)
      end
    end

    context "when XEN is installed" do
      let(:installed) { ["xen"] }

      context "and we are in a guest machine" do
        it "returns false" do
          allow(Yast::Arch).to receive(:is_xen0).and_return(false)
          expect(settings.virtual_proposal_required?).to eql(false)
        end
      end

      context "and we are in the host machine" do
        it "returns true" do
          allow(Yast::Arch).to receive(:is_xen0).and_return(true)
          expect(settings.virtual_proposal_required?).to eql(true)
        end
      end

      context "when KVM is installed" do
        let(:installed) { ["kvm"] }

        it "returns true" do
          expect(settings.virtual_proposal_required?).to eql(true)
        end
      end

      context "when QEMU is installed" do
        let(:installed) { ["qemu"] }

        it "returns true" do
          expect(settings.virtual_proposal_required?).to eql(true)
        end
      end
    end
  end
end
