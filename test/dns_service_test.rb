#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require_relative "test_helper"

Yast.import "UI"

class DummyDnsService < Yast::Module
  def initialize
    super
    Yast.include self, "network/services/dns.rb"
  end
end

describe "NetworkServicesDnsInclude" do
  subject { DummyDnsService.new }

  let(:ip) do
    Y2Network::ConnectionConfig::IPConfig.new(Y2Network::IPAddress.from_string("192.168.122.10/24"))
  end

  let(:conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |c|
      c.name = "eth0"
      c.interface = "eth0"
      c.ip = ip
      c.bootproto = Y2Network::BootProtocol::STATIC
      c.startmode = Y2Network::Startmode.create("auto")
      c.hostnames = ["yast.suse.com", "yast"]
    end
  end

  before do
    allow(Yast::Lan).to receive(:yast_config)
      .and_return(
        Y2Network::Config.new(
          interfaces:  Y2Network::InterfacesCollection.new([double(name: "eth0")]),
          connections: Y2Network::ConnectionConfigsCollection.new([conn]),
          source:      :testing
        )
      )
  end

  describe "#ValidateHostname" do
    it "allows empty hostname" do
      allow(Yast::UI).to receive(:QueryWidget).and_return("")

      expect(subject.ValidateHostname("", {})).to be true
    end

    it "allows valid characters in hostname" do
      allow(Yast::UI).to receive(:QueryWidget).and_return("sles")

      expect(subject.ValidateHostname("", {})).to be true
    end

    it "allows FQDN hostname if user asks for it" do
      allow(Yast::UI).to receive(:QueryWidget).and_return("sles.suse.de")

      expect(subject.ValidateHostname("", {})).to be true
    end

    it "disallows invalid characters in hostname" do
      allow(Yast::UI).to receive(:QueryWidget).and_return("suse_sles")

      expect(subject.ValidateHostname("", {})).to be false
    end
  end

  describe "#ValidateSearchList" do
    let(:widget_id) { "something" }
    let(:ui_event) { {} }

    it "allows empty value" do
      expect(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return("")

      expect(Yast::UI).to_not receive(:SetFocus)
      expect(Yast::Popup).to_not receive(:Error)

      expect(subject.ValidateSearchList(widget_id, ui_event)).to be true
    end

    it "allows valid values" do
      sl = "foo.example.com, example.org \n example.net \t example.not"
      expect(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return(sl)
      expect(Yast::Hostname).to receive(:CheckDomain).exactly(4).times.and_call_original

      expect(Yast::UI).to_not receive(:SetFocus)
      expect(Yast::Popup).to_not receive(:Error)

      expect(subject.ValidateSearchList(widget_id, ui_event)).to be true
    end

    it "allows a long list (256+) with many (6+) values" do
      ooo = "o" * 60
      long = "l#{ooo}ng.com"
      sl = "a.#{long} b.#{long} c.#{long} d.#{long} e.#{long} f.#{long} g.#{long}"
      expect(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return(sl)

      expect(Yast::UI).to_not receive(:SetFocus)
      expect(Yast::Popup).to_not receive(:Error)

      expect(subject.ValidateSearchList(widget_id, ui_event)).to be true
    end

    it "reports the first invalid value" do
      sl = "/.example.com /.example.org \n example.net \t example.not"
      expect(Yast::UI).to receive(:QueryWidget).with(Id(widget_id), :Value).and_return(sl)

      expect(Yast::UI).to receive(:SetFocus)
      err = /The search domain '\/.example.com' is invalid.\nA valid domain name.*/
      expect(Yast::Popup).to receive(:Error).with(err)

      expect(subject.ValidateSearchList(widget_id, ui_event)).to be false
    end
  end

  xdescribe "#propose_hostname_for" do
    pending
  end

  describe "#update_hostname_hosts" do

    let(:current_hostname) { "yast.suse.com" }

    before do
      allow(subject).to receive(:current_hostname).and_return(current_hostname)
    end

    context "when there was no static hostname" do
      it "returs false" do
        expect(subject.update_hostname_hosts("new-hostname")).to eql(false)
      end
    end

    context "when the hostname has not changed" do
      it "returns false" do
        expect(subject.update_hostname_hosts("yast.suse.com")).to eql(false)
      end
    end

    context "when a connection hostname was mapped to the modified hostname" do
      it "proposes the user to modify the connection hostname" do
        expect(Yast::Popup).to receive(:YesNo)
          .with(/Would you like to adapt it to 'new-hostname.suse.com'/).and_return(false)

        subject.update_hostname_hosts("new-hostname")
      end

      context "if the user accepts the proposed change" do
        it "modifies the connection hostname" do
          allow(Yast::Popup).to receive(:YesNo).and_return(true)

          expect { subject.update_hostname_hosts("new-hostname") }
            .to change { conn.hostname }.from("yast.suse.com").to("new-hostname.suse.com")
        end
      end
    end
  end
end
