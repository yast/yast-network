# Copyright (c) [2021] SUSE LLC
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
require "cfa/base_model"
require "y2network/interface_type"

Yast.import "Installation"

module CFA
  # Class to handle NetworkManager connection configuration files
  #
  # @see https://developer.gnome.org/NetworkManager/stable/nm-settings-keyfile.html
  # @example Reading the connection name
  #   file = NmConnection.new("/etc/NetworkManager/system-connections/eth0.nmconnection")
  #   file.load
  #   puts file.connection["id"]
  class NmConnection < BaseModel
    KNOWN_SECTIONS = [
      "bridge", "connection", "ethernet", "ipv4", "ipv6", "vlan", "wifi", "wifi_security"
    ].freeze
    SYSTEM_CONNECTIONS_DIR = "/etc/NetworkManager/system-connections".freeze

    class << self
      # Returns all connection definition files
      #
      # @return [Array<NmConnection>]
      def all
        directory = File.join(Yast::Installation.destdir, SYSTEM_CONNECTIONS_DIR)
        files = Dir[File.join(directory, "*.nmconnection")].to_a
        files.map { |f| new(f) }
      end
    end
    # Constructor
    #
    # @param path [String] File path
    # @param file_handler [.read, .write] Object to read/write the file.
    def initialize(path, file_handler: nil)
      # FIXME: The Networkmanager lense writes the values surrounded by double
      # quotes which is not valid
      super(AugeasParser.new("Desktop.lns"), path, file_handler: file_handler)
    end

    # Returns the augeas tree for the given section
    #
    # If the given section does not exist, it returns an empty one
    #
    # @param name [String] section name
    # @return [AugeasTree]
    def section_for(name)
      sname = name.gsub("_", "-")
      return data[sname] if data[sname]

      data[sname] ||= CFA::AugeasTree.new
    end

    # Sets an array's property under an specific section
    #
    # Array properties are written as a numbered variable. This method takes
    # care of numbering them according to the variable name.
    #
    # @example Write IPv4 addresses
    #   ipv4_addresses = ["192.168.1.100/24", "192.168.20.200/32"]
    #   file.add_collection("ipv4", "address", ipv4_addresses)
    #
    #   # Writes:
    #   # [ipv4]
    #   # address1="192.168.1.100/24"
    #   # address2="192.168.20.200/32"
    #
    # @param section [String] section name
    # @param name [String] variable name to be used
    # @param values [Array<String>] variable values
    def add_collection(section, name, values)
      section = section_for(section)

      values.each_with_index do |ip, index|
        section["#{name}#{index + 1}"] = ip
      end
    end

    TYPES_MAP = {
      wifi:     Y2Network::InterfaceType::WIRELESS,
      ethernet: Y2Network::InterfaceType::ETHERNET
    }.freeze
    private_constant :TYPES_MAP

    # Determines the interface type according to the content of the file
    #
    # @return [Y2Network::InterfaceType] Interface type
    def type
      TYPES_MAP[connection["type"]&.to_sym] ||
        Y2Network::InterfaceType::UNKNOWN
    end

    KNOWN_SECTIONS.each { |s| define_method(s) { section_for(s) } }
  end
end
