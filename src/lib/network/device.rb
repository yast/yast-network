require "yast/scr"
require "yast/path"

module Network
  class Device
    attr_reader :configuration
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def start
      save
      run "ifup '#{name}'"
    end

    def stop
      run "ifdown '#{name}'"
    end

    def global_address?
      run "ip -o addr show dev '#{name}' scope global up"
    end

    def configuration=(conf)
      conf.device = self
      @configuration = conf
    end

    def save
      @configuration.save
    end

  private
    RUN_PATH = Yast::Path.new(".target.bash")
    def run command
      Yast::SCR.Execute(RUN_PATH, command) == 0
    end
  end
end
