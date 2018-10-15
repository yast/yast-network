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

    # Parses wicked runtime configuration and returns list of ntp servers
    #
    # @param iface [String] network device
    # @return [Array<String>] list of NTP servers
    def parse_ntp_servers(iface)
      raise ArgumentError, "A network device has to be specified" if iface.nil? || iface.empty?
      raise "Parsing NTP Servers not supported for network service in use" if !NetworkService.is_wicked

      lease_files = ["ipv4", "ipv6"].map { |ip| "/var/lib/wicked/lease-#{iface}-dhcp-#{ip}.xml" }
      lease_files.find_all { |f| File.file?(f) }.reduce([]) do |stack, file|
        result = SCR.Execute(path(".target.bash_output"), "wicked xpath --file #{file} \"%{//ntp/server}\"")

        stack + result.fetch("stdout", "").split("\n")
      end
    end
  end
end
