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
  # @return Object
  def stub_scr_read(path_name)
    file = File.join(DATA_PATH, "scr_read", path_name[1..-1] + ".yml")
    info = YAML.load_file(file)
    path = Yast::Path.new(path_name)
    allow(Yast::SCR).to receive(:Read).with(path).and_return info
  end
end
