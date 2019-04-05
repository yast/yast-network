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
require "y2network/interface"
require "y2network/route"
Yast.import "FileUtils"

module Y2Network
  # This class represents a file containing a set of routes
  #
  # @example Reading the default location, i.e., /etc/sysconfig/network/routes
  #   file = Y2Network::SysconfigRoutesFile.new
  #   file.load
  #   file.routes.size #=> 2
  #
  # @example Reading routes for the interface eth1
  #   file = Y2Network::SysconfigRoutesFile.new("/etc/sysconfig/network/ifroute-eth1")
  #   file.load
  #   file.routes.size #=> 1
  class SysconfigRoutesFile
    DEFAULT_ROUTES_FILE = "/etc/sysconfig/network/routes".freeze

    # @return [Array<Route>] Routes
    attr_accessor :routes

    # @return [String] File path
    attr_reader :file_path

    # @param file_path [String] File path
    def initialize(file_path = DEFAULT_ROUTES_FILE)
      @register_agent = file_path != DEFAULT_ROUTES_FILE
      @file_path = file_path
    end

    # Loads routes from system
    #
    # @return [Array<Hash<String, String>>] list of hashes representing routes
    #                                       as provided by SCR agent.
    #                                       keys: destination, gateway, netmask, [device, [extrapara]]
    def load
      entries = with_registered_ifroute_agent(file_path) { |a| Yast::SCR.Read(a) }
      entries = entries ? normalize_entries(entries.uniq) : []
      @routes = entries.map { |r| build_route(r) }
    end

    # Writes configured routes
    #
    # @return [Boolean] true on success
    def save
      # create if not exists, otherwise backup
      if Yast::FileUtils.Exists(file_path)
        Yast::SCR.Execute(
          Yast::Path.new(".target.bash"),
          "/bin/cp #{file_path} #{file_path}.YaST2save"
        )
      else
        Yast::SCR.Write(Yast::Path.new(".target.string"), file_path, "")
      end

      with_registered_ifroute_agent(file_path) do |scr|
        # work around bnc#19476
        Yast::SCR.Write(Yast::Path.new(".target.string"), file_path, "")
        Yast::SCR.Write(scr, routes.map { |r| route_to_hash(r) })
      end
    end

    # Removes the file
    def remove
      return unless Yast::FileUtils.Exists(file_path)
      Yast::SCR.Execute(Yast::Path.new(".target.remove"), file_path)
    end

  private

    MISSING_VALUE = "-".freeze
    private_constant :MISSING_VALUE
    DEFAULT_DEST = "default".freeze
    private_constant :DEFAULT_DEST

    # Converts routes config as read from system into well-defined format
    #
    # Expects list of hashes as param. Hash should contain keys "destination",
    # "gateway", "netmask", "device", "extrapara"
    #
    # Currently it converts "destination" in CIDR format (<ip>/<prefix_len>)
    # and keeps just <ip> part in "destination" and puts "/<prefix_len>" into
    # "netmask"
    #
    # @param entries [Array<Hash>] in quad or CIDR flavors (see {#Routes})
    # @return [Array<Hash>] in quad or slash flavor
    def normalize_entries(entries)
      return entries if entries.nil? || entries.empty?

      entries.map do |entry|
        subnet, prefix = entry["destination"].split("/")

        next entry if prefix.nil?

        entry["destination"] = subnet
        entry["netmask"] = "/#{prefix}"

        entry
      end
    end

    # Given an IP and a netmask, returns a valid IPAddr object
    #
    # @param ip_str      [String] IP address; {MISSING_VALUE} means that the IP is not defined
    # @param netmask_str [String] Netmask; {MISSING_VALUE} means than no netmask was specified
    # @return [IPAddr,nil] The IP address or `nil` if the IP is missing
    def build_ip(ip_str, netmask_str = MISSING_VALUE)
      return nil if ip_str == MISSING_VALUE

      ip = IPAddr.new(ip_str)
      netmask_str == MISSING_VALUE ? ip : ip.mask(netmask_str)
    end

    # Build a route given a hash from the SCR agent
    #
    # @param hash [Hash] Hash from the `.routes` SCR agent
    # @return Route
    def build_route(hash)
      # TODO: check whether the iface is configured in the system
      iface = Interface.new(hash["device"])
      # normalized SCR output contains either subnet mask or /<prefix length> under
      # "netmask" key
      # TODO: this should be improved in normalize_routes
      mask = hash["netmask"].delete("/")

      Y2Network::Route.new(
        to:        hash["destination"] != DEFAULT_DEST ? build_ip(hash["destination"], mask) : :default,
        interface: iface,
        gateway:   build_ip(hash["gateway"], MISSING_VALUE),
        options:   hash["extrapara"] || ""
      )
    end

    # Returns a hash containing the route information
    #
    # Hash is provided in format suitable for .etc.routes SCR agent
    #
    # @param route [Y2Network::Route]
    # @return [Hash]
    def route_to_hash(route)
      hash = if route.default?
               { "destination" => "default", "netmask" => "-" }
             else
               dest = route.to
               # netmask column of routes file has been marked as deprecated -> using prefix
               { "destination" => "#{dest}/#{dest.prefix}", "netmask" => "-" }
             end

      hash.merge("options" => route.options) unless route.options.to_s.empty?
      hash.merge(
        "gateway" => route.gateway ? route.gateway.to_s : "-",
        "device"  => route.interface == :any ? "-" : route.interface.name
      )
    end

    NON_EMPTY_STR_TERM = Yast.term(:String, "^ \t\n").freeze
    WHITESPACE_TERM = Yast.term(:Whitespace).freeze
    OPTIONAL_WHITESPACE_TERM = Yast.term(:Optional, WHITESPACE_TERM).freeze
    ROUTES_CONTENT_TERM = Yast.term(
      :List,
      Yast.term(
        :Tuple,
        Yast.term(
          :destination,
          NON_EMPTY_STR_TERM
        ),
        WHITESPACE_TERM,
        Yast.term(:gateway, NON_EMPTY_STR_TERM),
        WHITESPACE_TERM,
        Yast.term(:netmask, NON_EMPTY_STR_TERM),
        OPTIONAL_WHITESPACE_TERM,
        Yast.term(
          :Optional,
          Yast.term(:device, NON_EMPTY_STR_TERM)
        ),
        OPTIONAL_WHITESPACE_TERM,
        Yast.term(
          :Optional,
          Yast.term(
            :extrapara,
            Yast.term(:String, "^\n")
          )
        )
      ),
      "\n"
    ).freeze

    # SCR agent for routes files definition
    def ifroute_term(path)
      raise ArgumentError if path.nil? || path.empty?

      Yast.term(
        :ag_anyagent,
        Yast.term(
          :Description,
          Yast.term(:File, path),
          "#\n", # TODO: document these arguments
          false,
          ROUTES_CONTENT_TERM
        )
      )
    end

    # Executes a block of passing the ifroute agent as a parameter
    #
    # @param file_path [String] Path to the routes file
    # @param block     [Proc] Code to execute
    # @return [Object] Returns the value of the block
    def with_registered_ifroute_agent(file_path, &block)
      scr_path = ifroute_agent_scr_path(file_path)
      block.call(scr_path)
    ensure
      Yast::SCR.UnregisterAgent(scr_path) if register_agent?
    end

    # Returns the path to the SCR agent
    #
    # If needed, it registers the agent
    #
    # @return [Yast::Path]
    def ifroute_agent_scr_path(file_path)
      return Yast::Path.new(".routes") unless register_agent?
      register_ifroute_agent_for_path(file_path)
    end

    # Determines whether the agent should be registered on the fly
    #
    # @return [Boolean] true if the agent needs to be registered
    def register_agent?
      @register_agent
    end

    # Registers SCR agent which is used for accessing particular ifroute-device
    # file
    #
    # @param file_path [String] full path to a file in routes format
    #   (e.g. /etc/sysconfig/network/ifroute-eth0)
    # @return [Yast::Path] SCR path of the agent
    # @raise  [RuntimeError] if it fails
    def register_ifroute_agent_for_path(file_path)
      # /etc/sysconfig/network/ifroute-eth0 define .ifroute-eth0 agent
      # TODO: collisions not handled
      scr_path = Yast::Path.new(".#{File.basename(file_path)}")
      Yast::SCR.RegisterAgent(scr_path, ifroute_term(file_path)) ||
        raise("Cannot register agent (#{scr_path})")
      scr_path
    end
  end
end
