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

require "yast"
require "y2issues"
require "y2network/config_writers/dns_writer"
require "y2network/config_writers/hostname_writer"
require "y2network/config_writers/interfaces_writer"
require "y2network/driver"
require "y2network/writing_result"

Yast.import "Host"

module Y2Network
  # This class is responsible for writing the configuration to the system
  #
  # It implements a {#write} method which receives a configuration object and
  # apply the changes to the system. Moreover, it is possible to write partial
  # configurations (the so-called 'sections'). For example, you might want to
  # just write the DNS configuration but keep the rest as it is.
  #
  # It is expect that a configuration writer exists for each supported backend
  # by inheriting from this class. It implements support for the common bits:
  # drivers, intefaces (udev rules), DNS and hostname settings. Of course, you are
  # not forced to use this class as a base.
  class ConfigWriter
    include Yast::Logger
    include Yast::I18n

    class << self
      # Returns a configuration writer for a given source
      #
      # @param source [Symbol] Source name (e.g., :wicked)
      # @return [Y2Network::ConfigWriters::ConfigWriter]
      #
      # @see Y2Network::ConfigWriters::ConfigWriter
      def for(source)
        require "y2network/#{source}/config_writer"
        modname = source.to_s.split("_").map(&:capitalize).join
        klass = Y2Network.const_get("#{modname}::ConfigWriter")
        klass.new
      end
    end

    # @return [Array<Symbol>] The different sections handled by the writer
    SECTIONS = [:routing, :drivers, :interfaces, :connections, :dns, :hostname].freeze

    # Writes the configuration into YaST network related modules
    #
    # @param config     [Y2Network::Config] Configuration to write
    # @param old_config [Y2Network::Config] Old configuration
    # @param only [Array<symbol>, nil] explicit sections to be written, by default if no
    #   parameter is given then all changes will be written
    #
    # @return [WritingResult] write result with issues list
    def write(config, old_config = nil, only: nil)
      sections = only || SECTIONS

      # TODO: Improve the loging using better format
      log.info "Writing configuration: #{config.inspect}\n"
      log.info "Old configuration: #{old_config.inspect}\n"

      log.info("Writing sections: #{sections.inspect}") if only

      issues_list = Y2Issues::List.new

      SECTIONS.each do |s|
        send(:"write_#{s}", config, old_config, issues_list) if sections.include?(s)
      end

      Yast::Host.Write(gui: false)

      WritingResult.new(config, issues_list)
    end

  private

    # Writes the routing configuration
    #
    # @param _config     [Y2Network::Config] configuration to write
    # @param _old_config [Y2Network::Config, nil] original configuration used for detecting changes
    def write_routing(_config, _old_config, _issues_list); end

    # Writes the connection configurations
    #
    # @param _config     [Y2Network::Config] configuration to write
    # @param _old_config [Y2Network::Config, nil] original configuration used for detecting changes
    def write_connections(_config, _old_config, _issues_list); end

    # Updates the DNS configuration
    #
    # @param config     [Y2Network::Config] Current config object
    # @param old_config [Y2Network::Config,nil] Config object with original configuration
    def write_dns(config, old_config, _issues_list)
      old_dns = old_config.dns if old_config
      writer = Y2Network::ConfigWriters::DNSWriter.new
      writer.write(config.dns, old_dns)
    end

    # Updates the Hostname configuration
    #
    # @param config     [Y2Network::Config] Current config object
    # @param old_config [Y2Network::Config,nil] Config object with original configuration
    def write_hostname(config, old_config, _issues_list)
      old_hostname = old_config.hostname if old_config
      writer = Y2Network::ConfigWriters::HostnameWriter.new
      writer.write(config.hostname, old_hostname)
    end

    # Updates the interfaces configuration and the routes associated with
    # them
    #
    # @param config     [Y2Network::Config] Current config object
    # @param _old_config [Y2Network::Config,nil] Config object with original configuration
    def write_interfaces(config, _old_config, _issues_list)
      writer = Y2Network::ConfigWriters::InterfacesWriter.new(reload: !Yast::Lan.write_only)
      writer.write(config.interfaces)
    end

    # Writes drivers options
    #
    # @param config     [Y2Network::Config] Current config object
    # @param _old_config [Y2Network::Config,nil] Config object with original configuration
    def write_drivers(config, _old_config, _issues_list)
      Y2Network::Driver.write_options(config.drivers)
    end

    # Writes ip forwarding setup
    #
    # TODO: extract this behaviour to a separate class.
    #
    # @param routing [Y2Network::Routing] routing configuration
    def write_ip_forwarding(routing, issues_list)
      sysctl_config = CFA::SysctlConfig.new
      sysctl_config.load
      sysctl_config.forward_ipv4 = routing.forward_ipv4
      sysctl_config.forward_ipv6 = routing.forward_ipv6
      sysctl_config.save unless sysctl_config.conflict?

      update_ip_forwarding((sysctl_config.forward_ipv4 ? "1" : "0"),
        :ipv4)
      update_ip_forwarding((sysctl_config.forward_ipv6 ? "1" : "0"),
        :ipv6)
      nil
    rescue CFA::AugeasSerializingError
      issues_list << Y2Issues::Issue.new(
        "Sysctl configuration update failed. The files might be corrupted",
        severity: :error
      )

      nil
    end

    IP_SYSCTL = {
      ipv4: "net.ipv4.ip_forward",
      ipv6: "net.ipv6.conf.all.forwarding"
    }.freeze

    # Updates the IP forwarding configuration of the running kernel
    #
    # @param value [String] "1" (enable) or "0" (disable).
    # @param type  [Symbol] :ipv4 or :ipv6
    def update_ip_forwarding(value, type)
      key = IP_SYSCTL[type]
      Yast::SCR.Execute(Yast::Path.new(".target.bash"),
        "/usr/sbin/sysctl -w #{key}=#{value.shellescape}")
    end
  end
end
