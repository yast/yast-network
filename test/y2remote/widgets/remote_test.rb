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
require "y2remote/widgets/remote"
require "y2remote/remote"

require "cwm/rspec"

describe Y2Remote::Widgets do
  let(:remote) { Y2Remote::Remote.instance }
  before do
    stub_const("Yast::Packages", double.as_null_object)
  end

  describe Y2Remote::Widgets::RemoteSettings do
    include_examples "CWM::CustomWidget"

    describe "#init" do
      it "disables the web checkbox if vnc is not enabled" do
        expect(subject)
      end
    end

    describe "#handle" do
      it "returns nil" do
        expect(subject.handle("any")).to eq(nil)
      end

      context "when vnc access is disallowed" do
        it "disables the web access checkbox" do
          expect_any_instance_of(Y2Remote::Widgets::AllowWeb).to receive(:disable)

          subject.handle("ID" => :disallow)
        end
      end
      context "when vnc access is allowed" do
        it "enables the web access checkbox" do
          expect_any_instance_of(Y2Remote::Widgets::AllowWeb).to receive(:enable).twice

          subject.handle("ID" => :allow_with_vncmanager)
          subject.handle("ID" => :allow_without_vncmanager)
        end
      end
    end

    describe "#store" do
      let(:disallow) { false }
      let(:web_access) { false }
      let(:with_manager) { false }

      before do
        allow(subject).to receive(:disallow?).and_return(disallow)
        allow(subject).to receive(:allow_manager?).and_return(with_manager)
        allow(subject).to receive(:allow_web?).and_return(web_access)
      end

      context "when the option selected is" do
        context "when disallow" do
          let(:disallow) { true }

          it "disables vnc" do
            subject.store

            expect(remote.modes).to be_empty
          end

          it "returns nil" do
            expect(subject.store).to eq(nil)
          end
        end

        context "when vnc without manager" do
          let(:disallow) { false }

          it "enables vnc" do
            subject.store

            expect(remote.modes).to contain_exactly(Y2Remote::Modes::VNC.instance)
          end

          it "returns nil" do
            expect(subject.store).to eq(nil)
          end

          context "and web access is enabled" do
            let(:web_access) { true }

            it "enables vnc and web access" do
              subject.store

              expect(remote.modes).to contain_exactly(
                Y2Remote::Modes::VNC.instance, Y2Remote::Modes::Web.instance
              )
            end
          end

        end

        context "when vnc with session management" do
          let(:disallow) { false }
          let(:with_manager) { true }

          it "enables vnc manager mode" do
            subject.store

            expect(remote.modes).to contain_exactly(Y2Remote::Modes::Manager.instance)
          end

          it "returns nil" do
            expect(subject.store).to eq(nil)
          end

          context "and web access is enabled" do
            let(:web_access) { true }

            it "enables vnc with session management and web access" do
              subject.store

              expect(remote.modes).to contain_exactly(
                Y2Remote::Modes::Manager.instance, Y2Remote::Modes::Web.instance
              )
            end
          end
        end
      end
    end
  end

  describe Y2Remote::Widgets::AllowWeb do
    include_examples "CWM::CheckBox"
  end

  describe Y2Remote::Widgets::RemoteFirewall do
    let("firewall_widget") { { "help" => "", "custom_widget" => Yast::Term.new(:Empty) } }
    include_examples "CWM::CustomWidget"

    before do
      allow(Yast::CWMFirewallInterfaces).to receive(:CreateOpenFirewallWidget)
        .and_return(firewall_widget)
      allow(Yast::CWMFirewallInterfaces).to receive(:OpenFirewallInit)
      allow(Yast::CWMFirewallInterfaces).to receive(:OpenFirewallHandle)
      allow(Yast::CWMFirewallInterfaces).to receive(:StoreAllowedInterfaces)
    end

    describe ".new" do
      it "initializes the widget" do
        expect(Yast::CWMFirewallInterfaces).to receive(:CreateOpenFirewallWidget)
          .with("services" => Y2Remote::Remote::FIREWALL_SERVICES, "display_details" => true)

        described_class.new
      end
    end

    describe ".handle" do
      it "handles changes in the widget" do
        expect(Yast::CWMFirewallInterfaces).to receive(:OpenFirewallHandle)
          .with(firewall_widget, "", "event")
        subject.handle("event")
      end
    end

    describe ".store" do
      it "enables vnc firewall services in the allowed interfaces" do
        expect(Yast::CWMFirewallInterfaces).to receive(:StoreAllowedInterfaces)
          .with(Y2Remote::Remote::FIREWALL_SERVICES)

        subject.store
      end
    end
  end
end
