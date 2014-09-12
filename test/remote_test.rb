#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require_relative "SCRStub"

module Yast
  import "Remote"
  import "Linuxrc"
  import "Package"
  import "Packages"

  RSpec.configure do |c|
    c.include SCRStub
  end

  describe Remote do
    describe ".Reset" do
      context "on vnc installation" do
        before do
          allow(Linuxrc).to receive(:vnc).and_return true
        end

        it "enables remote administration" do
          Remote.Reset
          expect(Remote.IsEnabled).to eql(true)
        end
      end

      context "on local installation" do
        before do
          allow(Linuxrc).to receive(:vnc).and_return false
        end

        it "disables remote administration" do
          Remote.Reset
          expect(Remote.IsEnabled).to eql(false)
        end
      end
    end

    describe ".configure_display_manager" do
      before do
        stub_scr_write
        stub_scr_read(".etc.xinetd_conf.services")
        allow(Package).to receive(:Installed).with("xinetd").and_return true
      end

      context "with VNC enabled" do
        before do
          Remote.Enable
        end

        it "installs packages provided by Packages.vnc_packages" do
          allow(Service).to receive(:Enable).and_return true

          expect(Packages).to receive(:vnc_packages).and_return %w(some names)
          expect(Package).to receive(:InstallAll).with(%w(some names)).and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "enables the services" do
          allow(Packages).to receive(:vnc_packages)
          allow(Package).to receive(:InstallAll).and_return true

          expect(Service).to receive(:Enable).with("display-manager").and_return true
          expect(Service).to receive(:Enable).with("xinetd").and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "writes the VNC configuration" do
          allow(Packages).to receive(:vnc_packages)
          allow(Service).to receive(:Enable).twice.and_return true
          allow(Package).to receive(:InstallAll).and_return true

          expect(Remote.configure_display_manager).to eql(true)

          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")).to eq("yes")
          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE")).to eq("yes")

          # vnc1 and vnchttp1 services are enabled
          services = written_value_for(".etc.xinetd_conf.services")
          services = services.select {|s| s["service"] =~ /vnc/ }
          expect(services.map {|s| s["enabled"]}).to eq([true, true])
        end
      end

      context "with VNC disabled" do
        before do
          Remote.Disable
        end

        it "does not install packages" do
          expect(Package).to_not receive(:InstallAll)
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "does not enable services" do
          expect(Service).to_not receive(:Enable)
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "updates the configuration to not use VNC" do
          expect(Remote.configure_display_manager).to eql(true)

          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")).to eq("no")
          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE")).to eq("no")

          # vnc1 and vnchttp1 services are enabled
          services = written_value_for(".etc.xinetd_conf.services")
          services = services.select {|s| s["service"] =~ /vnc/ }
          expect(services.map {|s| s["enabled"]}).to eq([false, false])
        end
      end
    end
  end
end
