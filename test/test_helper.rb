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

srcdir = File.expand_path("../src", __dir__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

# Ensure the tests runs with english locales
ENV["LC_ALL"] = "en_US.UTF-8"
ENV["LANG"] = "en_US.UTF-8"

# load it early, so other stuffs are not ignored
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  # track all ruby files under src
  SimpleCov.track_files("#{srcdir}/**/*.rb")

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["CI"] || ENV["COVERAGE_LCOV"]
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end

require "yast"
require "yast/rspec"
Yast.import "NetworkInterfaces"
Yast.import "Lan"

require "y2storage"

require_relative "scr_stub"
require_relative "support/network_helpers"

RSpec.configure do |c|
  c.extend Yast::I18n # available in context/describe
  c.include Yast::I18n
  c.include SCRStub
  c.include Yast::RSpec::NetworkHelpers
  c.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  c.before do
    Yast::Lan.clear_configs
    Y2Network::Hwinfo.reset
    allow(Yast::NetworkInterfaces).to receive(:Write)
    allow(Y2Network::Hwinfo).to receive(:hwinfo_from_hardware)
    Y2Storage::StorageManager.create_test_instance
  end
end

DATA_PATH = File.join(__dir__, "data")

# stub module to prevent its Import
# Useful for modules from different yast packages, to avoid build dependencies
def stub_module(name)
  stubbed_class = Class.new do
    # fake respond_to? to avoid failure of partial doubles
    singleton_class.define_method(:respond_to?) do |_mname, _include_all = nil|
      true
    end

    # needed to fake at least one class method to avoid Yast.import
    singleton_class.define_method(:fake_method) do
    end
  end
  Yast.const_set(name.to_sym, stubbed_class)
end

# stub classes from other modules to speed up a build
stub_module("AutoInstall")
stub_module("Profile")

# A two level section/key => value store
# to remember values of /etc/sysconfig/network/ifcfg-*
class SectionKeyValue
  def initialize
    @sections = {}
  end

  def sections
    @sections.keys
  end

  def keys(section)
    @sections[section].keys
  end

  def get(section, key)
    @sections[section][key]
  end

  def set(section, key, value)
    section_hash = @sections[section] ||= {}
    section_hash[key] = value
  end
end
