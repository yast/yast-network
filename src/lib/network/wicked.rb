# encoding: utf-8

require "yast"

module Yast
  module Wicked
    BASH_PATH = Path.new(".target.bash")

    # Reloads configuration for each device named in devs
    #
    # @param devs [Array] list of device names
    # @return [Boolean] true if configuration was reloaded; false otherwise
    def reload_config(devs)
      raise ArgumentError if devs.nil?
      return true if devs.empty?

      SCR.Execute(BASH_PATH, "wicked ifreload #{devs.join(" ")}").zero?
    end
  end
end
