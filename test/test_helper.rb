srcdir = File.expand_path("../../src", __FILE__)
y2dirs = ENV.fetch("Y2DIR", "").split(":")
ENV["Y2DIR"] = y2dirs.unshift(srcdir).join(":")

require "yast"
require "yast/rspec"

# Ensure the tests runs with english locales
ENV["LC_ALL"] = "en_US.UTF-8"

require_relative "SCRStub"

RSpec.configure do |c|
  c.extend Yast::I18n # available in context/describe
  c.include Yast::I18n
  c.include SCRStub
end

# stub module to prevent its Import
# Useful for modules from different yast packages, to avoid build dependencies
def stub_module(name)
  Yast.const_set name.to_sym, Class.new { def self.fake_method; end }
end

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

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  # For coverage we need to load all ruby files
  # Note that clients/ are excluded because they run too eagerly by design
  Dir["#{srcdir}/{include,modules}/**/*.rb"].each do |f|
    require_relative f
  end

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
  end
end
