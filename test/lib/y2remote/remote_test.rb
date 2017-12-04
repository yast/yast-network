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

require_relative "../../test_helper.rb"
require "y2remote/remote"

describe Y2Remote::Remote do
  subject { described_class.instance }

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
      let(:modes) { [:vnc, :web] }

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

  describe ".enable_mode" do
    context "given a vnc running mode" do
      context "when it is :vnc" do
        it "returns the current modes if already present" do
          allow(subject).to receive(:modes).and_return([:vnc, :web])
          expect(subject.modes).to_not receive(:delete)

          expect(subject.enable_mode(:vnc)).to contain_exactly(:vnc, :web)
        end

        it "removes :manager if present from the modes list" do
          allow(subject).to receive(:modes).and_return([:manager])

          expect(subject.enable_mode(:vnc)).to contain_exactly(:vnc)
        end

        it "adds the :vnc mode to the list of modes if not present" do
          subject.disable!
          expect(subject.enable_mode(:vnc)).to contain_exactly(:vnc)
          # Check that is not added twice
          expect(subject.enable_mode(:vnc)).to contain_exactly(:vnc)
        end
      end

      context "when it is :manager" do
        it "returns the current modes if already present" do
          allow(subject).to receive(:modes).and_return([:manager, :web])
          expect(subject.modes).to_not receive(:delete)

          expect(subject.enable_mode(:manager)).to contain_exactly(:manager, :web)
        end

        it "removes :vnc if present from the modes list" do
          allow(subject).to receive(:modes).and_return([:vnc])

          expect(subject.enable_mode(:manager)).to contain_exactly(:manager)
        end

        it "adds the :manager mode to the list of modes if not present" do
          subject.disable!
          expect(subject.enable_mode(:manager)).to contain_exactly(:manager)
          # Check that is not added twice
          expect(subject.enable_mode(:manager)).to contain_exactly(:manager)
        end
      end

      context "when it is :web" do
        it "returns the current modes if already present" do
          allow(subject).to receive(:modes).and_return([:manager, :web])
          expect(subject.modes).to_not receive(:delete)

          expect(subject.enable_mode(:manager)).to contain_exactly(:manager, :web)
        end

        it "adds the :web mode to the list of modes if not present" do
          subject.disable!
          expect(subject.enable_mode(:web)).to contain_exactly(:web)
          # Check that is not added twice
          expect(subject.enable_mode(:web)).to contain_exactly(:web)
        end
      end
    end
  end

  describe ".read" do
    it "returns true" do
      allow(subject).to receive(:xdm_enabled?).and_return(false)

      expect(subject.read).to eq(true)
    end

    context "when xdm & the remote access are enabled" do
      it "initializes the list of modes depending on the enabled ones" do
        allow(subject).to receive(:xdm_enabled?).and_return(true)
        allow(subject).to receive(:display_manager_remote_access?).and_return(true)

        expect(Y2Remote::Modes).to receive(:running_modes).and_return([:vnc])

        subject.read

        expect(subject.modes).to contain_exactly(:vnc)
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
end
