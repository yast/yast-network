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
require "y2network/can_be_copied"

module Y2Network
  # This class represents a driver for an interface
  #
  # It is composed of a kernel module name and a string representing the module options
  class Driver
    include CanBeCopied

    class << self
      # Returns a driver using the information from the system
      #
      # @param name [String] Driver's name
      def from_system(name)
        params = Yast::SCR.Read(Yast::Path.new(".modules.options.#{name}"))
        params_string = params.map { |k, v| "#{k}=#{v}" }.join(" ")
        new(name, params_string)
      end

      # Writes driver options to the underlying system
      #
      # @param drivers [Y2Network::Driver] Drivers to write options
      def write_options(drivers)
        drivers.each(&:write_options)
        commit
      end

      # Commits drivers options to disk
      def commit
        Yast::SCR.Write(Yast::Path.new(".modules"), nil)
      end
    end

    # @return [String] Kernel module name
    attr_accessor :name
    # @return [String] Kernel module parameters
    attr_accessor :params

    # Constructor
    #
    # @param name   [String] Driver name
    # @param params [String] Driver parameters (e.g., "csum=1 debug=16")
    def initialize(name, params = "")
      @name = name
      @params = params
    end

    # Determines whether two drivers are equal
    #
    # @param other [Object] Driver to compare with
    # @return [Boolean] true if +other+ is a Driver instance with the same name and params;
    #   false otherwise.
    def ==(other)
      return false unless other.is_a?(Driver)

      name == other.name && params == other.params
    end

    # Adds driver parameters to be written to the underlying system
    #
    # Parameters are not written to disk until Y2Network::Driver.commit
    # is called. The reason is that writing them is an expensive operation, so it is
    # better to write parameters for all drivers at the same time.
    #
    # You might prefer to use {.write_options} instead.
    #
    # @see Y2Network::Driver.commit
    def write_options
      parts = params.split(/ +/)
      params_hash = parts.each_with_object({}) do |param, hash|
        key, value = param.split("=")
        hash[key] = value.to_s
      end
      Yast::SCR.Write(Yast::Path.new(".modules.options.#{name}"), params_hash)
    end

    # eql? (hash key equality) should alias ==, see also
    # https://ruby-doc.org/core-2.3.3/Object.html#method-i-eql-3F
    alias_method :eql?, :==
  end
end
