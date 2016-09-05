# encoding: utf-8

require "yast"

module Yast
  module Wicked
    BASH_PATH = Path.new(".target.bash")

    # Reloads configuration for each device named in devs
    #
    # @devs [Array] list of device names
    # @return true if configuration was reloaded
    def reload_config(devs)
      raise ArgumentError if devs.nil?
      return true if devs.empty?

      SCR.Execute(BASH_PATH, "wicked ifreload #{devs.join(" ")}").zero?
    end

    # Reloads configuration for each device named in devs
    #
    # @devs [Array] list of device names
    # @return [Boolean] true if devices bring down; false otherwise
    def bring_down(devs)
      raise ArgumentError if devs.nil?
      return true if devs.empty?

      SCR.Execute(BASH_PATH, "wicked ifdown #{devs.join(" ")}").zero?
    end

    # Reloads configuration for each device named in devs
    #
    # @devs [Array] list of device names
    # @return [Boolean] true if devices bring up; false otherwise
    def bring_up(devs)
      raise ArgumentError if devs.nil?
      return true if devs.empty?

      SCR.Execute(BASH_PATH, "wicked ifup #{devs.join(" ")}").zero?
    end
  end
end
