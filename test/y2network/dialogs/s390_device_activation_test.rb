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
require "cwm/rspec"

require "y2network/dialogs/s390_device_activation"
require "y2network/interface_config_builder"

describe Y2Network::Dialogs::S390DeviceActivation do
  let(:builder) do
    Y2Network::InterfaceConfigBuilder.for("qeth").tap do |builder|
      builder.name = "0.0.0700:0.0.0701:0.0.0702"
    end
  end

  let(:activator) { Y2Network::S390DeviceActivator.for(builder) }
  let(:yast_config) { Y2Network::Config.new(source: :wicked, s390_devices: s390_devices) }
  let(:s390_devices) { Y2Network::S390GroupDevicesCollection.new([qeth_0700]) }
  let(:qeth_0700) { Y2Network::S390GroupDevice.new("qeth", "0.0.0700:0.0.0701:0.0.0702") }
  let(:new_interface) { Y2Network::Interface.new("eth4") }
  let(:interfaces_reader) do
    double(Y2Network::Wicked::InterfacesReader,
      interfaces: Y2Network::InterfacesCollection.new([new_interface]))
  end

  before do
    allow(subject).to receive(:reader).and_return(interfaces_reader)
  end

  subject { described_class.new(activator) }

  include_examples "CWM::Dialog"

  describe ".new" do
    it "creates a proposal for the configured device" do
      expect(activator).to receive(:propose!)
      described_class.new(activator)
    end
  end

  describe "#run" do
    let(:stderr) { "" }
    let(:status) { 0 }
    let(:configure_output) { ["", stderr, status] }
    let(:dialog_action) { :next }

    before do
      allow(subject).to receive(:config).and_return(yast_config)
      allow(activator).to receive(:configure).and_return(configure_output)
      allow(activator).to receive(:configured_interface).and_return(new_interface.name)
      allow(subject).to receive(:cwm_show).and_return(dialog_action)
      allow(Yast::Popup).to receive(:ReallyAbort)
    end

    context "when going :next" do
      it "tries to activate the s390 device" do
        expect(activator).to receive(:configure)
        subject.run
      end

      context "when activated the device" do
        it "sets the builder name with the associated interface" do
          subject.run
          expect(builder.name).to eql(new_interface.name)
        end

        it "adds the new interface to the config" do
          expect(yast_config.interfaces).to receive(:<<).with(new_interface)
          subject.run
          expect(qeth_0700.interface).to eq(new_interface.name)
        end

        it "refresh the s390 group device online status" do
          expect { subject.run }.to change { qeth_0700.online }.from(false).to(true)
        end

        it "returns :next" do
          expect(subject.run).to eql(:next)
        end
      end

      context "when failed the activation" do
        before do
          allow(subject).to receive(:cwm_show).twice.and_return(:next, :abort)
          allow(Yast2::Popup).to receive(:show)
        end

        let(:stderr) { "activation error" }
        let(:status) { 38 }

        it "popups an error" do
          expect(Yast2::Popup).to receive(:show)
          subject.run
        end

        it "continues showing the dialog until going :next success or aborted" do
          expect(subject).to receive(:cwm_show).twice.and_return(:next, :abort)
          subject.run
        end
      end
    end
  end

  describe "#abort_handler" do
    it "asks for abort confirmation" do
      expect(Yast::Popup).to receive(:ReallyAbort).with(true)

      subject.abort_handler
    end
  end
end
