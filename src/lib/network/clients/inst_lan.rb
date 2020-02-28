# Copyright (c) [2020] SUSE LLC
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

Yast.import "UI"
Yast.import "Lan"
Yast.import "GetInstArgs"
Yast.import "NetworkService"

module Yast
  # Client for configuring the network during installation.
  #
  # If the network configuration is managed by NetworkManager or some
  # connection config is already present the client skip the configuration
  # sequence.
  #
  # The configuration sequence can be forced passing the 'skip_detection'
  # argument.
  #
  # @example calling the client forcing the configuration sequence
  #   Yast::WFM.CallFunction("inst_lan", [args.merge("skip_detection" => true)])
  #
  # @example firsboot xml forcing the configuration sequence
  #   <module>
  #     <label>Network</label>
  #      <name>inst_lan</name>
  #      <arguments>
  #        <skip_detection>true</skip_detection>
  #      </arguments>
  #   </module>
  class InstLanClient < Client
    include Logger

    class << self
      attr_accessor :configured
    end

    def initialize
      textdomain "network"

      Yast.include self, "network/lan/wizards.rb"
    end

    def main
      ret = nil
      log.info("----------------------------------------")
      log.info("Lan module started")

      manual_conf_request = GetInstArgs.argmap["skip_detection"] || false
      log.info("Lan module forces manual configuration: #{manual_conf_request}")

      if !manual_conf_request
        log.info("Configured network found: #{network_configured?}")
        ret = GetInstArgs.going_back ? :back : :next if network_configured?
      end

      ret ||= LanSequence()

      log.info("Lan module finished, ret = #{ret}")
      log.info("----------------------------------------")

      ret
    end

  private

    # Convenience method that checks whether there is some connection
    # configuration present in the system
    #
    # @return [Boolean] true when there is some connection present in yast
    #   config; false otherwise
    def connections_configured?
      # Ensure we read the current network config
      Lan.Read(:cache)
      !(Lan.yast_config&.connections || []).empty?
    end

    # It returns whether the network has been configured or not. It returns
    # true in case NetworkManager is in use, otherwise returns whehter there is
    # some connection configured
    #
    # @see connections_configured?
    def network_configured?
      # keep network configuration state to gurantee same behavior when
      # walking :back in installation workflow
      return self.class.configured unless self.class.configured.nil?

      self.class.configured = NetworkService.network_manager? ? true : connections_configured?
    end

    def reset_config_state
      self.class.configured = nil
    end
  end
end
