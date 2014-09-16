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

    # TODO: this whole describe block is just a direct translation from the old
    # testsuite. I needs to be rewritten to better describe the behavior of
    # the method
    describe ".SetSecurityTpe" do
      let(:result) { Remote.SetSecurityType(server_args, sec_type) }
      let(:default_xvnc_args) {
        "-noreset -inetd -once -query localhost -geometry 1024x768 -depth 16"
      }

      context "with invalid sec_type parameter" do
        let(:sec_type) { "INVALID" }

        context "with empty arguments" do
          let(:server_args) { "" }

          it "returns empty arguments" do
            expect(result).to eq("")
          end
        end

        context "with default arguments from Xvnc package" do
          let(:server_args) { default_xvnc_args }

          it "returns the provided arguments" do
            expect(result).to eq(server_args)
          end
        end
      end

      context "with a valid sec_type parameter" do
        let(:sec_type) { Remote.SEC_NONE }

        context "with empty arguments" do
          let(:server_args) { "" }

          it "returns only the corresponding 'securitytypes' argument" do
            expect(result).to eq("-securitytypes none")
          end
        end

        context "with default arguments from Xvnc package" do
          let(:server_args) { default_xvnc_args }

          it "returns the provided arguments plus the corresponding 'securitytypes'" do
            expect(result).to eq("#{server_args} -securitytypes none")
          end
        end

        context "with arguments including a space-separated 'securitytype'" do
          let(:server_args) { "-securitytpes vncauth #{default_xvnc_args}" }

          it "strips the 'securitytypes' argument and adds the correct one" do
            expect(result).to eq("#{server_args} -securitytypes none")
          end
        end

        context "with two dashes and upper case 'securitytypes' as argument" do
          let(:server_args) { "--securityTypes=VNCAUTH" }

          it "ignores the provided 'securitytypes' argument and returns the correct one" do
            expect(result).to eq("-securitytypes none")
          end
        end

        context "with 'securitytpes' argument present twice and with camel case" do
          let(:server_args) { "securityTypes=VNCAUTH -rfbauth /var/lib/nobody/.vnc/passwd -securitytypes=vncauth" }

          it "strips both occurrences of 'securitytypes' and adds the correct one" do
            expect(result).to eq("-rfbauth /var/lib/nobody/.vnc/passwd -securitytypes none")
          end
        end
      end
    end

    describe "#restart_service" do
      context "when remote administration is being enabled" do
        before(:each) do
          Remote.Enable()
          expect(SystemdTarget).to receive(:set_default).with("graphical").and_return(true)
          expect(Service).to receive(:Restart).with("xinetd").and_return(true)
        end

        context "when display-manager service is active" do
          it "adjusts needed services and warns the user" do
            expect(Service).to receive(:active?).with("display-manager").and_return(true)
            expect(Service).to receive(:Reload).with("display-manager").and_return(true)
            expect(Report).to receive(:Warning)
            Remote.restart_service
          end
        end

        context "when display-manager service is inactive" do
          it "adjusts needed services" do
            expect(Service).to receive(:active?).with("display-manager").and_return(false)
            expect(Service).to receive(:Restart).with("display-manager").and_return(true)
            Remote.restart_service
          end
        end
      end

      context "when remote adminitration is being disabled" do
        before(:each) do
          Remote.Disable()
        end

        context "xinetd is active" do
          it "reloads the xinetd service" do
            expect(Service).to receive(:active?).with("xinetd").and_return(true)
            expect(Service).to receive(:Reload).with("xinetd").and_return(true)
            Remote.restart_service
          end
        end

        context "xinetd is inactive" do
          it "does nothing with services" do
            expect(Service).to receive(:active?).with("xinetd").and_return(false)
            expect(Service).not_to receive(:Reload)
            Remote.restart_service
          end
        end
      end
    end

  end
end
