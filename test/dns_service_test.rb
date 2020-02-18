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

class DummyDnsService < Yast::Module
  def initialize
    Yast.include self, "network/services/dns.rb"
  end
end

describe "NetworkServicesDnsInclude" do
  subject { DummyDnsService.new }

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
end
