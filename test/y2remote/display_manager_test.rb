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

require_relative "../test_helper"
require "y2remote/remote"

describe Y2Remote::DisplayManager do
  subject { described_class.instance }

  describe "#enabled?" do
    let(:service_enabled) { false }

    before do
      stub_const("Yast::Service", double(Enabled: service_enabled))
    end

    context "when the display manager's service is disabled" do
      it "returns false" do
        expect(subject.enabled?).to eq(false)
      end
    end

    context "when the display manager's service is enabled" do
      let(:service_enabled) { true }

      it "returns true" do
        expect(subject.enabled?).to eq(true)
      end
    end
  end

  describe "#remote_access?" do
    let(:remote_access_path) { ".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS" }
    let(:remote_access_value) { "yes" }
    let(:service_enabled) { true }

    before do
      allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(remote_access_path))
        .and_return(remote_access_value)
      stub_const("Yast::Service", double(Enabled: service_enabled))
    end

    context "when display manager's service ist not enabled" do
      let(:service_enabled) { false }

      it "returns false" do
        expect(subject.remote_access?).to eql(false)
      end
    end

    context "when the display manager's service is enabled" do
      context "and the remote access is enabled in /etc/sysconfig/displaymanager" do
        it "returns true" do
          expect(subject.remote_access?).to eq(true)
        end
      end

      context "and the remote access is not enabled in /etc/sysconfig/displaymanager" do
        let(:remote_access_value) { "no" }

        it "returns false" do
          expect(subject.remote_access?).to eq(false)
        end
      end
    end
  end

  describe "#restart" do
    let(:service_active) { false }
    let(:service_restarted) { false }
    let(:service_reloaded) { false }
    let(:service_mock) do
      {
        active?: service_active,
        Reload:  service_reloaded,
        Restart: service_restarted
      }
    end

    before do
      stub_const("Yast::Service", double(service_mock))
      stub_const("Yast::Report", double(Warning: true))
      allow(Yast::Service).to receive(:active?).and_return(service_active)
      allow(Yast::Report).to receive(:Warning)
      allow(subject).to receive(:report_cannot_restart)
    end

    context "when the display manager's service is active" do
      let(:service_active) { true }

      it "tries to reload the service" do
        expect(Yast::Service).to receive(:Reload).and_return(true)

        subject.restart
      end

      it "reports and error if the service was not reloaded" do
        expect(subject).to receive(:report_cannot_restart)

        subject.restart
      end

      it "warns the user about having to restart or log in again to changes be applied" do
        expect(Yast::Report).to receive(:Warning).once

        subject.restart
      end
    end

    context "when the display manager's service is not active" do
      it "restarts the display manager's service" do
        expect(Yast::Service).to receive(:Restart).and_return(false)

        subject.restart
      end

      it "reports an error if the service restart fails" do
        expect(Yast::Service).to receive(:Restart).and_return(false)
        expect(subject).to receive(:report_cannot_restart)

        subject.restart
      end
    end
  end

  describe "#write_remote_access" do
    let(:remote_access_path) { ".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS" }
    let(:root_remote_login_path) { ".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE" }

    before do
      allow(Yast::SCR).to receive(:Write)
    end

    context "when the given 'allowed' param is true" do
      it "writes DISPLAYMANAGER_REMOTE_ACCESS with 'yes' in /etc/sysconfig/displaymanager" do
        expect(Yast::SCR).to receive(:Write).with(Yast::Path.new(remote_access_path), "yes")

        subject.write_remote_access(true)
      end

      it "writes DISPLAYMANAGER_ROOT_LOGIN_REMOTE with 'yes' in /etc/sysconfig/displaymanager" do
        expect(Yast::SCR).to receive(:Write).with(Yast::Path.new(root_remote_login_path), "yes")

        subject.write_remote_access(true)
      end

      it "flushes /etc/sysconfig/displaymanager after writing" do
        expect(Yast::SCR).to receive(:Write)
          .with(Yast::Path.new(".sysconfig.displaymanager"), nil)

        subject.write_remote_access(true)
      end
    end

    context "when the given 'allowed' param is not true" do
      it "writes DISPLAYMANAGER_REMOTE_ACCESS with 'no' in /etc/sysconfig/displaymanager" do
        expect(Yast::SCR).to receive(:Write).with(Yast::Path.new(remote_access_path), "no")

        subject.write_remote_access(false)
      end

      it "writes DISPLAYMANAGER_ROOT_LOGIN_REMOTE with 'no' in /etc/sysconfig/displaymanager" do
        expect(Yast::SCR).to receive(:Write).with(Yast::Path.new(root_remote_login_path), "no")

        subject.write_remote_access(false)
      end

      it "flushes /etc/sysconfig/displaymanager after writing" do
        expect(Yast::SCR).to receive(:Write)
          .with(Yast::Path.new(".sysconfig.displaymanager"), nil)

        subject.write_remote_access(false)
      end
    end
  end
end
