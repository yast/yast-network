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

      context "vncmanager mode is on, web off" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xvnc.socket").and_return false
          allow(Service).to receive(:Enabled).with("xvnc-novnc.socket").and_return false
          allow(Service).to receive(:Enabled).with("vncmanager").and_return true
        end

        it "recognizes vncmanager mode, web off" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(true)
          expect(Remote.IsWebVncEnabled).to eql(false)
        end
      end

      context "xvnc mode is on, web off" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xvnc.socket").and_return true
          allow(Service).to receive(:Enabled).with("xvnc-novnc.socket").and_return false
          allow(Service).to receive(:Enabled).with("vncmanager").and_return false
        end

        it "recognizes xvnc mode, web off" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(false)
          expect(Remote.IsWebVncEnabled).to eql(false)
        end
      end

      context "vncmanager mode is on, web on" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xvnc.socket").and_return false
          allow(Service).to receive(:Enabled).with("xvnc-novnc.socket").and_return true
          allow(Service).to receive(:Enabled).with("vncmanager").and_return true
        end

        it "recognizes vncmanager mode, web on" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(true)
          expect(Remote.IsWebVncEnabled).to eql(true)
        end
      end

      context "xvnc mode is on, web on" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xvnc.socket").and_return true
          allow(Service).to receive(:Enabled).with("xvnc-novnc.socket").and_return true
          allow(Service).to receive(:Enabled).with("vncmanager").and_return false
        end

        it "recognizes xvnc mode, web on" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.EnabledVncManager).to eql(false)
          expect(Remote.IsWebVncEnabled).to eql(true)
        end
      end

      context "vnc is off" do
        before do
          allow(Service).to receive(:Enabled).with("display-manager").and_return true
          allow(Service).to receive(:Enabled).with("xvnc.socket").and_return false
          allow(Service).to receive(:Enabled).with("xvnc-novnc.socket").and_return false
          allow(Service).to receive(:Enabled).with("vncmanager").and_return false
        end

        it "recognizes disabled mode" do
          Remote.Read
          expect(Remote.IsEnabled).to eql(false)
          expect(Remote.EnabledVncManager).to eql(false)
          expect(Remote.IsWebVncEnabled).to eql(false)
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

    describe ".enable_disable_web_access" do
      context "with VNC enabled and web access enabled" do
        before do
          Remote.Enable
          Remote.EnableWebVnc
        end

        it "enables web access" do
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.IsWebVncEnabled).to eql(true)
        end
      end

      context "with VNC enabled and web access disables" do
        before do
          Remote.Enable
          Remote.DisableWebVnc
        end

        it "disables web access" do
          expect(Remote.IsEnabled).to eql(true)
          expect(Remote.IsWebVncEnabled).to eql(false)
        end
      end
    end

    describe ".configure_display_manager" do
      before do
        stub_scr_write
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
          expect(Service).to receive(:Enable).with("xvnc.socket").and_return true
          expect(Service).to receive(:Disable).with("vncmanager").and_return true
          expect(Service).to receive(:Disable).with("xvnc-novnc.socket").and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "writes the VNC configuration" do
          allow(Service).to receive(:Enable).twice.and_return true
          allow(Service).to receive(:Disable).twice.and_return true
          allow(Package).to receive(:InstallAll).and_return true

          expect(Remote.configure_display_manager).to eql(true)

          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")).to eq("yes")
          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE")).to eq("yes")
        end
      end

      context "with VNC enabled with session management" do
        before do
          Remote.EnableVncManager
        end

        it "installs packages provided by Packages.vnc_packages" do
          allow(Service).to receive(:Enable).and_return true
          allow(Service).to receive(:Disable).and_return true

          expect(Package).to receive(:InstallAll).with(%w(some names vncmanager)).and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "enables the services" do
          allow(Package).to receive(:InstallAll).and_return true

          expect(Service).to receive(:Enable).with("display-manager").and_return true
          expect(Service).to receive(:Enable).with("vncmanager").and_return true
          expect(Service).to receive(:Disable).with("xvnc.socket").and_return true
          expect(Service).to receive(:Disable).with("xvnc-novnc.socket").and_return true
          expect(Remote.configure_display_manager).to eql(true)
        end

        it "writes the VNC configuration" do
          allow(Service).to receive(:Enable).twice.and_return true
          allow(Service).to receive(:Disable).twice.and_return true
          allow(Package).to receive(:InstallAll).and_return true

          expect(Remote.configure_display_manager).to eql(true)

          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_REMOTE_ACCESS")).to eq("yes")
          expect(written_value_for(".sysconfig.displaymanager.DISPLAYMANAGER_ROOT_LOGIN_REMOTE")).to eq("yes")
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

          it "adjusts vncmanager and display-manager service and warns the user" do
            expect(SystemdTarget).to receive(:set_default).with("graphical").and_return(true)
            expect(Service).to receive(:Restart).with("xvnc.socket").and_return(true)
            expect(Service).to receive(:Reload).with("display-manager").and_return(true)
            expect(Report).to receive(:Warning)
            Remote.restart_services
          end
        end

        context "when display-manager service is inactive" do
          let(:active_display_manager) { false }

          it "adjusts xvnc and display-manager services" do
            expect(SystemdTarget).to receive(:set_default).with("graphical").and_return(true)
            expect(Service).to receive(:Restart).with("xvnc.socket").and_return(true)
            expect(Service).to receive(:Restart).with("display-manager").and_return(true)
            Remote.restart_services
          end
        end
      end

      context "when remote adminitration is being disabled" do
        before do
          Remote.Disable()
          allow(Service).to receive(:Reload).and_return(true)
          allow(Service).to receive(:Stop).and_return(true)
        end

        it "disables vncmanager" do
          expect(Service).to receive(:Stop).with("vncmanager").and_return(true)
          Remote.restart_services
        end

      end
    end
  end
end
