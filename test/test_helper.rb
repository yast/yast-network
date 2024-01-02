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

RSpec.configure do |c|
  c.extend Yast::I18n # available in context/describe
  c.include Yast::I18n
  c.include SCRStub
  c.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  c.before do
    Yast::Lan.clear_configs
    Y2Network::Hwinfo.reset
    allow(Yast::NetworkInterfaces).to receive(:Write)
    allow(Y2Network::Hwinfo).to receive(:hwinfo_from_hardware)
    allow(Yast::Host).to receive(:load_hosts).and_return(true)
    Y2Storage::StorageManager.create_test_instance
  end
end

DATA_PATH = File.join(__dir__, "data")

# stub classes from other modules to avoid build dependencies
Yast::RSpec::Helpers.define_yast_module("AutoInstall",
  methods: [:issues_list, :valid_imported_values])
Yast::RSpec::Helpers.define_yast_module("Profile", methods: [:current])
Yast::RSpec::Helpers.define_yast_module("Proxy", methods: [:Export, :Import, :Read, :Write])

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

# mock empty class to avoid build dependency on yast2-installation
module Installation
  module Console
    module Plugins
      class MenuPlugin
        def inspect
          "just fake method for testing"
        end
      end
    end
  end
end
