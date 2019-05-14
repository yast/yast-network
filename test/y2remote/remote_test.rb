#!/usr/bin/env rspec

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require_relative "../test_helper.rb"
require "y2remote/remote"

describe Y2Remote::Remote do
  let(:vnc) { Y2Remote::Modes::Web.instance }
  let(:manager) { Y2Remote::Modes::Manager.instance }
  let(:web) { Y2Remote::Modes::VNC.instance }
  let(:display_manager) { Y2Remote::DisplayManager.instance }
  subject { described_class.instance }

  before do
    stub_const("Yast::Packages", double.as_null_object)
  end

  describe ".disabled?" do
    let(:modes) { [] }

    before do
      allow(subject).to receive(:modes).and_return(modes)
    end

    context "when vnc is not enabled" do
      it "returns true" do
        expect(subject.disabled?).to eq(true)
      end
    end

    context "when some vnc mode is enabled" do
      let(:modes) { [vnc, web] }

      it "returns false" do
        expect(subject.disabled?).to eq(false)
      end
    end
  end

  describe ".disable!" do
    it "sets vnc to be disabled" do
      subject.disable!

      expect(subject.modes).to be_empty
    end
  end

  describe ".enabled?" do
    let(:modes) { [] }

    before do
      allow(subject).to receive(:modes).and_return(modes)
    end

    context "when vnc is disabled" do
      it "returns false" do
        expect(subject.enabled?).to eq(false)
      end
    end

    context "when some vnc mode is enabled" do
      let(:modes) { [:vnc, :web] }

      it "returns true" do
        expect(subject.enabled?).to eq(true)
      end
    end
  end

  describe ".enable_manager!" do
    it "returns the current modes if already present" do
      allow(subject).to receive(:modes).and_return([manager, web])
      expect(subject.modes).to_not receive(:delete)

      expect(subject.enable_manager!).to contain_exactly(manager, web)
    end

    it "removes the VNC instance if present from the modes list" do
      allow(subject).to receive(:modes).and_return([vnc])

      expect(subject.enable_manager!).to contain_exactly(manager)
    end

    it "adds the :manager mode to the list of modes if not present" do
      subject.disable!
      expect(subject.enable_manager!).to contain_exactly(manager)
      # Check that is not added twice
      expect(subject.enable_manager!).to contain_exactly(manager)
    end
  end

  describe ".enable!" do
    let(:web) { Y2Remote::Modes::Web.instance }
    let(:manager) { Y2Remote::Modes::Manager.instance }
    let(:vnc) { Y2Remote::Modes::VNC.instance }

    it "returns the current modes if already present" do
      allow(subject).to receive(:modes).and_return([vnc, web])
      expect(subject.modes).to_not receive(:delete)

      expect(subject.enable!).to contain_exactly(vnc, web)
    end

    it "removes :manager if present from the modes list" do
      allow(subject).to receive(:modes).and_return([manager])

      expect(subject.enable!).to contain_exactly(vnc)
    end

    it "adds the :vnc mode to the list of modes if not present" do
      subject.disable!
      expect(subject.enable!).to contain_exactly(vnc)
      # Check that is not added twice
      expect(subject.enable!).to contain_exactly(vnc)
    end
  end

  describe ".enable_web!" do
    let(:web) { Y2Remote::Modes::Web.instance }
    let(:manager) { Y2Remote::Modes::Manager.instance }

    it "returns the current modes if already present" do
      allow(subject).to receive(:modes).and_return([manager, web])
      expect(subject.modes).to_not receive(:delete)

      expect(subject.enable_web!).to contain_exactly(manager, web)
    end

    it "adds the :web mode to the list of modes if not present" do
      subject.disable!
      expect(subject.enable_web!).to contain_exactly(web)
      # Check that is not added twice
      expect(subject.enable_web!).to contain_exactly(web)
    end
  end

  describe ".read" do
    it "returns true" do
      allow(display_manager).to receive(:enabled?).and_return(false)

      expect(subject.read).to eq(true)
    end

    context "when the display manager allowes remote access" do
      it "initializes the list of modes depending on the enabled ones" do
        allow(display_manager).to receive(:remote_access?).and_return(true)

        expect(Y2Remote::Modes).to receive(:running_modes).and_return([vnc])

        subject.read

        expect(subject.modes).to contain_exactly(vnc)
      end
    end
  end

  describe ".write" do
    let(:progress) { instance_double("Yast::Progress") }
    let(:normal_mode) { false }

    before do
      allow(progress)
      allow(subject).to receive(:restart_services)
      allow(subject).to receive(:configure_display_manager).and_return(true)
      allow(Yast::Mode).to receive(:normal).and_return(normal_mode)
    end

    it "configures the vnc and display manager config" do
      expect(subject).to receive(:configure_display_manager)

      subject.write
    end

    it "returns false if failed when configuring the display manager & vnc" do
      expect(subject).to receive(:configure_display_manager).and_return(false)

      expect(subject.write).to eq(false)
    end

    it "returns true when finish successfully" do
      expect(subject.write).to eq(true)
    end

    context "in normal Mode" do
      let(:normal_mode) { true }

      it "restarts VNC & xdm services" do
        expect(subject).to receive(:restart_services)

        subject.write
      end
    end

    context "in other Mode than normal" do
      it "does not restart any service" do
        expect(subject).to_not receive(:restart_services)

        subject.write
      end
    end
  end

  describe ".proposed?" do
    context "when the remote config has been already proposed" do

      it "returns true" do
        subject.proposed = true

        expect(subject.proposed?).to eql(true)
      end
    end

    context "when the remote config has not been proposed yet" do
      it "returns false" do
        subject.proposed = false

        expect(subject.proposed?).to eql(false)
      end
    end
  end

  describe ".propose!" do
    let(:web) { Y2Remote::Modes::Web.instance }
    let(:linuxrc) { double("Yast::Linuxrc") }

    context "when the config has been already proposed" do
      it "returns false" do
        subject.proposed = true

        expect(subject.propose!).to eq(false)
      end
    end

    context "when the config has been not been proposed yet" do
      let(:linuxrc_vnc) { false }

      before do
        allow(linuxrc).to receive(:vnc).and_return(linuxrc_vnc)
      end

      it "sets the config as already proposed" do
        subject.proposed = false
        subject.propose!
        expect(subject.proposed?).to eq(true)
      end

      context "and vnc option has been given by linuxrc" do
        let(:linuxrc_vnc) { true }

        it "sets vnc to be enabled" do
          subject.proposed = false

          expect(subject).to receive(:disable!)

          subject.propose!
        end
      end

      context "and vnc option has not been given by linuxrc" do
        it "sets vnc to be disabled" do
          subject.proposed = false

          expect(subject).to receive(:disable!)
          subject.propose!
        end
      end
    end
  end

  describe ".reset!" do
    it "forces a new proposal" do
      expect(subject).to receive(:propose!)

      subject.reset!
    end
  end

  describe ".restart_services" do
    let(:modes) { [vnc, web] }

    before do
      allow(subject).to receive(:modes).and_return(modes)
      allow(Yast2::Systemd::Target).to receive(:set_default)
      allow(display_manager).to receive(:restart)
      allow(Y2Remote::Modes).to receive(:restart_modes)
    end

    context "when vnc is enabled" do
      it "sets graphical as the default systemd target" do
        expect(Yast2::Systemd::Target).to receive(:set_default)
          .with(Y2Remote::Remote::GRAPHICAL_TARGET)
        subject.restart_services
      end

      it "starts the enabled modes and stops the rest" do
        expect(Y2Remote::Modes).to receive(:restart_modes).with(modes)
        subject.restart_services
      end

      it "restarts the display manager" do
        expect(display_manager).to receive(:restart)
        subject.restart_services
      end
    end

    context "when vnc is disabled" do
      let(:modes) { [] }

      it "stops the running modes" do
        expect(Y2Remote::Modes).to receive(:restart_modes).with(modes)
        subject.restart_services
      end
    end
  end

  describe ".configure_display_manager" do
    let(:modes) { [vnc, web] }
    before do
      allow(subject).to receive(:modes).and_return(modes)
      allow(display_manager).to receive(:write_remote_access)
      allow(Y2Remote::Modes).to receive(:update_status)
    end

    context "when vnc is disabled" do
      let(:modes) { [] }

      it "disables all the vnc modes that are still enabled" do
        expect(Y2Remote::Modes).to receive(:update_status).with([])
        subject.configure_display_manager
      end

      it "disables the remote access in the display manager" do
        expect(display_manager).to receive(:write_remote_access).with(false)

        subject.configure_display_manager
      end
    end

    context "when vnc is enabled" do
      before do
        allow(Yast::Package).to receive(:InstallAll)
        allow(subject).to receive(:required_packages).and_return("packages")
      end

      it "tries to install all the required packages for the enabled modes" do
        expect(Yast::Package).to receive(:InstallAll).with("packages")

        subject.configure_display_manager
      end

      context "if all the required packages are installed" do
        before do
          allow(Yast::Package).to receive(:InstallAll).and_return(true)
        end

        it "enables the configured vnc modes" do
          expect(Y2Remote::Modes).to receive(:update_status).with([vnc, web])
          subject.configure_display_manager
        end

        it "enables the remote access in the display manager" do
          expect(display_manager).to receive(:write_remote_access).with(true)

          subject.configure_display_manager
        end
      end

      context "if some required package was not installed or available" do
        it "returns false" do
          expect(Yast::Package).to receive(:InstallAll).and_return(false)
          subject.configure_display_manager
        end
      end
    end
  end
end
