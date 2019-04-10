require "yaml"

# Helpers for stubbing several agent operations.
#
# Must be included in the configure section of RSpec.
#
# @example usage
#     RSpec.configure do |c|
#       c.include SCRStub
#     end
#
#     describe "Keyboard" do
#       it "uses loadkeys" do
#         expect_to_execute(/loadkeys/)
#         Keyboard.Set
#       end
#     end
#
module SCRStub
  DATA_PATH = File.join(File.expand_path(File.dirname(__FILE__)), "data")

  # Ensures that non-stubbed SCR calls still work as expected after including
  # the module in the testsuite
  def self.included(testsuite)
    testsuite.before(:each) do
      allow(Yast::SCR).to receive(:Read).and_call_original
      allow(Yast::SCR).to receive(:Write).and_call_original
      allow(Yast::SCR).to receive(:Execute).and_call_original
    end
  end

  # Stub all calls to SCR.Write storing the value for future comparison
  def stub_scr_write
    @written_values = {}
    allow(Yast::SCR).to receive(:Write) do |*args|
      @written_values[args[0].to_s] = args[1]
    end
  end

  # Value written by a stubbed call to SCR.Read
  #
  # @param key used in the call to SCR.Write
  def written_value_for(key)
    @written_values[key]
  end

  # Stubs calls to SCR.Read returning the object stored in the corresponding
  # yaml file.
  #
  # Yaml files are stored in the scr_read subdirectory of the data directory
  # and named after the yast path (without the leading '.').
  #
  # @param path_name [String] an SCR path, eg. ".etc.xinetd_conf.services"
  #
  # @return Object
  def yaml_stub_scr_read(path_name)
    file = File.join(DATA_PATH, "scr_read", path_name[1..-1] + ".yml")
    info = YAML.load_file(file)
    mock_path(path_name, info)
  end

  # Stubs calls to SCR.Read. Returns file content as a list of lines.
  #
  # Should be equivalent to ycp's SCR::Read(".target.string", path)
  #
  # @param path_name [String] an absolute filesystem path, eg. "/etc/sysctl.conf"
  #
  # @return [Array] list of lines
  def string_stub_scr_read(path_name)
    file = File.join(DATA_PATH, "scr_read", path_name[1..-1])
    info = File.read(file)
    mock_path(".target.string", info, path_name)
  end

  # Stubs SCR.Read for given target file using given content
  def mock_path(target, content, params = nil)
    path = Yast::Path.new(target)

    if params
      allow(Yast::SCR).to receive(:Read).with(path, params).and_return content
    else
      allow(Yast::SCR).to receive(:Read).with(path).and_return content
    end
  end
end

module YaPINetworkStub
  def stub_network_reads
    allow(Yast::DNS).to receive(:Read)
    allow(Yast::NetworkInterfaces).to receive(:CleanCacheRead)
    allow(Yast::LanItems).to receive(:Read)
  end

  def stub_clean_cache(device)
    allow(Yast::NetworkInterfaces).to receive(:CleanCacheRead)
    allow(Yast::NetworkInterfaces).to receive(:Add)
    allow(Yast::NetworkInterfaces).to receive(:Edit).with(device).and_return false
    allow(Yast::NetworkInterfaces).to receive(:Name).with(device).and_return false
  end

  def stub_write_interfaces
    expect(Yast::NetworkInterfaces).to receive("Commit")
    expect(Yast::NetworkInterfaces).to receive(:Write).with("")
    expect(Yast::Service).to receive(:Restart).with("network")
  end
end
