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

Yast.import "Report"

class NetworkLanCmdlineIncludeClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/cmdline.rb"
  end
end

describe "Yast::NetworkLanCmdlineInclude" do
  subject { NetworkLanCmdlineIncludeClass.new }

  describe "#validateId" do
    it "reports error and returns false if options missing \"id\"" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({}, [])).to eq false
    end

    it "reports error and returns false if options \"id\" is not number" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({ "id" => "zzz" }, [])).to eq false
    end

    it "reports error and returns false if options \"id\" do not fit config size" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({ "id" => "5" }, [])).to eq false
    end

    it "returns true otherwise" do
      expect(Yast::Report).to_not receive(:Error)

      expect(subject.validateId({ "id" => "0" }, ["0" => { "id" => "0" }])).to eq true
    end

  end
end
