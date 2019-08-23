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

require_relative "../test_helper"
require "cfa/generic_sysconfig"
require "cfa/memory_file"

describe CFA::GenericSysconfig do
  def file_path(filename)
    File.join(SCRStub::DATA_PATH, filename)
  end

  describe "#attributes" do
    subject { described_class.new(file_path("dhcp.original")) }
    it "prints only real attributes of file" do
      subject.load
      expect(subject.attributes.size).to eq 2
    end
  end

  describe ".merge_files" do
    around do |test|
      ::FileUtils.cp(file_path("dhcp.original"), file_path("dhcp"))
      test.call
      ::FileUtils.rm(file_path("dhcp"))
    end

    it "merges attributes from modified file to original one" do
      described_class.merge_files(file_path("dhcp"), file_path("dhcp.modified"))

      expect(File.read(file_path("dhcp"))).to eq File.read(file_path("dhcp.expected"))
    end

    context "if the original is missing" do
      before do
        ::FileUtils.rm(file_path("dhcp"))
      end

      it "copies the modified file" do
        described_class.merge_files(file_path("dhcp"), file_path("dhcp.modified"))

        expect(File.read(file_path("dhcp"))).to eq File.read(file_path("dhcp.modified"))
      end
    end
  end
end
