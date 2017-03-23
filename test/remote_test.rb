#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

stub_module "Packages"

module Yast
  import "Remote"
  import "Linuxrc"

  describe Remote do
    before do
      allow(Packages).to receive(:vnc_packages).and_return %w(some names)
    end

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

    describe ".Read" do
      before do
        allow(Yast::SCR).to receive(:Read).with(
          Yast::Path.new(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")
        ).and_return("yes")

        allow(Yast::SCR).to receive(:Read).with(
          Yast::Path.new(".sysconfig.displaymanager.DISPLAYMANAGER")
        ).and_return("xdm")

        allow(SuSEFirewall).to receive(:Read).and_return true
      end

      context "vncmanager mode is on" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xinetd").and_return true
          allow(Service).to receive(:Enabled).with("vncmanager").and_return true

          allow(Yast::SCR).to receive(:Read).with(
            Yast::Path.new(".etc.xinetd_conf.services")
          ).and_return(
            [{ "service" => "vnc1", "enabled" => false }, { "service" => "vnchttpd1", "enabled" => true }]
          )
        end

        it "recognizes vncmanager mode" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(true)
        end
      end

      context "xinetd mode is on" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xinetd").and_return true
          allow(Service).to receive(:Enabled).with("vncmanager").and_return false

          allow(Yast::SCR).to receive(:Read).with(
            Yast::Path.new(".etc.xinetd_conf.services")
          ).and_return(
            [{ "service" => "vnc1", "enabled" => true }, { "service" => "vnchttpd1", "enabled" => true }]
          )
        end

        it "recognizes xinetd mode" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(false)
        end
      end

      context "xinetd service is off" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xinetd").and_return false
          allow(Service).to receive(:Enabled).with("vncmanager").and_return false

          allow(Yast::SCR).to receive(:Read).with(
            Yast::Path.new(".etc.xinetd_conf.services")
          ).and_return(
            [{ "service" => "vnc1", "enabled" => true }, { "service" => "vnchttpd1", "enabled" => true }]
          )
        end

        it "recognizes disabled mode" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(false)
        end
      end
    end

    describe ".enable_disable_remote_administration" do
      context "with VNC enabled and with session management" do
        before do
          Remote.EnableVncManager
        end

        it "enables vnc without session management" do
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(true)
        end
      end

      context "with VNC enabled and without session management" do
        before do
          Remote.Enable
        end

        it "enables vnc without session management" do
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(false)
        end
      end

      context "with VNC disabled" do
        before do
          Remote.Disable
        end

        it "disables vnc" do
          expect(Remote.IsEnabled).to eql(false)
        end
      end

    end

    describe ".configure_display_manager" do
      before do
        stub_scr_write
        yaml_stub_scr_read(".etc.xinetd_conf.services")
        allow(Package).to receive(:Installed).and_return true
      end

      context "with VNC enabled without session management" do
        before do
          Remote.Enable
        end

        it "installs packages provided by Packages.vnc_packages" do
          allow(Service).to receive(:Enable).and_return true
          allow(Service).to receive(:Disable).and_return true

          expect(Package).to receive(:InstallAll).with(%w(some names)).and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "enables the services" do
          allow(Package).to receive(:InstallAll).and_return true

          expect(Service).to receive(:Enable).with("display-manager").and_return true
          expect(Service).to receive(:Enable).with("xinetd").and_return true
          expect(Service).to receive(:Disable).with("vncmanager").and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "writes the VNC configuration" do
          allow(Service).to receive(:Enable).twice.and_return true
          allow(Service).to receive(:Disable).once.and_return true
          allow(Package).to receive(:InstallAll).and_return true

          expect(Remote.configure_display_manager).to eql(true)

          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")).to eq("yes")
          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE")).to eq("yes")

          # vnc1 and vnchttpd1 services are enabled
          services = written_value_for(".etc.xinetd_conf.services")
          services = services.select { |s| s["service"] =~ /vnc/ }.map { |s| [s["service"], s["enabled"]] }.to_h
          expect(services).to eq("vnc1" => true, "vnchttpd1" => true)
        end
      end

      context "with VNC enabled with session management" do
        before do
          Remote.EnableVncManager
        end

        it "installs packages provided by Packages.vnc_packages" do
          allow(Service).to receive(:Enable).and_return true

          expect(Package).to receive(:InstallAll).with(%w(some names vncmanager)).and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "enables the services" do
          allow(Package).to receive(:InstallAll).and_return true

          expect(Service).to receive(:Enable).with("display-manager").and_return true
          expect(Service).to receive(:Enable).with("xinetd").and_return true
          expect(Service).to receive(:Enable).with("vncmanager").and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "writes the VNC configuration" do
          allow(Service).to receive(:Enable).exactly(3).times.and_return true
          allow(Package).to receive(:InstallAll).and_return true

          expect(Remote.configure_display_manager).to eql(true)

          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")).to eq("yes")
          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE")).to eq("yes")

          # vnchttpd1 service is enabled but vnc1 is disabled
          services = written_value_for(".etc.xinetd_conf.services")
          services = services.select { |s| s["service"] =~ /vnc/ }.map { |s| [s["service"], s["enabled"]] }.to_h
          expect(services).to eq("vnc1" => false, "vnchttpd1" => true)
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

          # vnc1 and vnchttpd1 services are disabled
          services = written_value_for(".etc.xinetd_conf.services")
          services = services.select { |s| s["service"] =~ /vnc/ }.map { |s| [s["service"], s["enabled"]] }.to_h
          expect(services).to eq("vnc1" => false, "vnchttpd1" => false)
        end
      end
    end

    describe "#restart_services" do
      context "when remote administration is being enabled" do
        before(:each) do
          Remote.Enable
          allow(Service).to receive(:active?).with("display-manager").and_return(active_display_manager)
        end

        context "when display-manager service is active" do
          let(:active_display_manager) { true }

          it "adjusts xinetd and display-manager  services and warns the user" do
            expect(SystemdTarget).to receive(:set_default).with("graphical").and_return(true)
            expect(Service).to receive(:Restart).with("xinetd").and_return(true)
            expect(Service).to receive(:Reload).with("display-manager").and_return(true)
            expect(Report).to receive(:Warning)
            Remote.restart_services
          end
        end

        context "when display-manager service is inactive" do
          let(:active_display_manager) { false }

          it "adjusts xinetd and display-manager services" do
            expect(SystemdTarget).to receive(:set_default).with("graphical").and_return(true)
            expect(Service).to receive(:Restart).with("xinetd").and_return(true)
            expect(Service).to receive(:Restart).with("display-manager").and_return(true)
            Remote.restart_services
          end
        end
      end

      context "when remote adminitration is being disabled" do
        before do
          Remote.Disable()
          allow(Service).to receive(:active?).with("xinetd").and_return(active_xinetd)
          # do not call reload or stop
          allow(Service).to receive(:Reload).and_return(true)
          allow(Service).to receive(:Stop).and_return(true)
        end

        context "xinetd is active" do
          let(:active_xinetd) { true }

          it "reloads the xinetd service" do
            expect(Service).to receive(:Reload).with("xinetd").and_return(true)
            Remote.restart_services
          end

          it "disables vncmanager" do
            expect(Service).to receive(:Stop).with("vncmanager").and_return(true)
            Remote.restart_services
          end
        end

        context "xinetd is inactive" do
          let(:active_xinetd) { false }

          it "does nothing with xinetd service" do
            expect(Service).not_to receive(:Reload)
            Remote.restart_services
          end

          it "disables vncmanager" do
            expect(Service).to receive(:Stop).with("vncmanager").and_return(true)
            Remote.restart_services
          end
        end
      end
    end
  end
end
