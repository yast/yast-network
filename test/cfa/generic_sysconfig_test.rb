#!/usr/bin/env rspec

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
  end
end
