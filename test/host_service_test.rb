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

class DummyHostService < Yast::Module
  def initialize
    super
    Yast.include self, "network/services/host.rb"
  end
end

describe "NetworkServicesHostInclude" do
  subject { DummyHostService.new }

  describe "#encode_hosts_line" do
    it "encodes canonical name even aliases" do
      canonical = "žížala.jůlinka.go.home"
      aliases = "žížala jůlinka	earthworm"

      result = subject.encode_hosts_line(canonical, aliases.split)

      expect(result).to eql(
        "xn--ala-qma83eb.xn--jlinka-3mb.go.home xn--ala-qma83eb xn--jlinka-3mb earthworm"
      )
    end

    it "returns empty string when invalid arguments were passed" do
      result = subject.encode_hosts_line(nil, nil)

      expect(result).to be_empty
    end
  end
end
