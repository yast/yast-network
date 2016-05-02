#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

module Yast
  import "Remote"
  import "Linuxrc"
  import "Package"
  import "Packages"

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
          services = services.select { |s| s["service"] =~ /vnc/ }
          expect(services.map { |s| s["enabled"] }).to eq([true, true])
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
          services = services.select { |s| s["service"] =~ /vnc/ }
          expect(services.map { |s| s["enabled"] }).to eq([false, false])
        end
      end
    end

    describe "#restart_services" do
      context "when remote administration is being enabled" do
        before(:each) do
          Remote.Enable()
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
        before(:each) do
          Remote.Disable()
          allow(Service).to receive(:active?).with("xinetd").and_return(active_xinetd)
        end

        context "xinetd is active" do
          let(:active_xinetd) { true }

          it "reloads the xinetd service" do
            expect(Service).to receive(:Reload).with("xinetd").and_return(true)
            Remote.restart_services
          end
        end

        context "xinetd is inactive" do
          let(:active_xinetd) { false }

          it "does nothing with services" do
            expect(Service).not_to receive(:Reload)
            Remote.restart_services
          end
        end
      end
    end
  end
end
