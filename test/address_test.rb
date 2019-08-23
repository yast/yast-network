#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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

class DummyClassForAddressTest < Yast::Module
  def initialize
    Yast.include self, "network/lan/address.rb"
  end
end

describe "NetworkLanAddressInclude" do
  subject { DummyClassForAddressTest.new }

  describe "#update_hostname" do
    let(:ip) { "1.1.1.1" }
    let(:initial_hostname) { "initial.hostname.com" }
    let(:new_hostname) { "new.hostname.com" }

    before(:each) do
      allow(Yast::LanItems)
        .to receive(:ipaddr)
        .and_return(ip)
      allow(subject)
        .to receive(:initial_hostname)
        .and_return(initial_hostname)
      allow(Yast::Host)
        .to receive(:names)
        .and_call_original
      allow(Yast::Host)
        .to receive(:names)
        .with(ip)
        .and_return(["#{initial_hostname} custom-name"])
    end

    context "when ip has not changed" do
      it "drops old /etc/hosts record if hostname was changed" do
        expect(Yast::Host)
          .to receive(:remove_ip)
          .with(ip)
        expect(Yast::Host)
          .to receive(:Update)
          .with(initial_hostname, new_hostname, ip)

        subject.send(:update_hostname, ip, new_hostname)
      end
    end

    context "when ip has changed" do
      it "keeps names if there is no change in hostname" do
        new_ip = "2.2.2.2"

        original_names = Yast::Host.names(ip)
        subject.send(:update_hostname, new_ip, initial_hostname)

        expect(Yast::Host.names(new_ip)).to eql original_names
      end

      it "does not crash when no hostnames exist for old ip and new hostname is not set" do
        new_ip = "2.2.2.2"

        # targeted especially against newly created devices ;-)
        allow(Yast::LanItems)
          .to receive(:ipaddr)
          .and_return("")

        expect { subject.send(:update_hostname, new_ip, "") }.not_to raise_error
      end
    end
  end
end
