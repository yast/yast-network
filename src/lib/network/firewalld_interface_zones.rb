# encoding: utf-8
#
# ***************************************************************************
#
# Copyright (c) 2017 SUSE LLC.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 or 3 of the GNU General
# Public License as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact SUSE LLC.
#
# To contact SUSE about this file by physical or electronic mail,
# you may find current contact information at www.suse.com
#
# ***************************************************************************

require "yast"
require "singleton"
require "y2firewall/firewalld"

Yast.import "NetworkInterfaces"

module Yast
  # This class is responsible of update the state of network interfaces zones
  # in firewalld.
  class FirewalldInterfaceZones
    include Singleton
    include Logger
    include I18n
    # Maintains the original interface zones map.
    attr_accessor :original

    # Constructor
    def initialize
      read
    end

    # Sets the current configuration as the original.
    def read
      @original = current
    end

    # Perform in firewalld the changes between the original and current state.
    def apply_changes
      removed_interfaces.each { |i| remove_interface(i) }
      added_interfaces.each { |i| change_interface(i) }
      modified_interfaces.each { |i| change_interface(i) }
    end

    # Obtain current interfaces zones.
    #
    # return [Hash<String, Hash<String, String>]
    def current
      interface_zone = {}

      NetworkInterfaces.List("").map do |name|
        interface_zone[name] =
          {
            id:          name,
            description: get_value(name, "NAME"),
            zone:        get_value(name, "ZONE")
          }
      end

      interface_zone
    end

  private

    # @return [Y2Firewalld::Firewalld] singleton instance
    def firewalld
      Y2Firewall::Firewalld.instance
    end

    # Convenience method for obtain the value of a specific network interface
    # attribute.
    #
    # @param name [String] network interface name
    # @param value [String] network interface attribute
    # @return [String] the value of the given attribute
    def get_value(name, attribute)
      NetworkInterfaces::GetValue(name, attribute)
    end

    # @return [Array<String>] removed interface names
    def removed_interfaces
      original.keys - current.keys
    end

    # @return [Array<String>] added interface names
    def added_interfaces
      current.keys - original.keys
    end

    # @return [Array<String>] modified interface names
    def modified_interfaces
      current.select { |k, v| original[k] && (original[k][:zone] != v[:zone]) }.keys
    end

    # Convenience method for remove an interface from a firewalld zone
    def remove_interface(name)
      log.info("Removing interface #{name} from its original zone #{original[name][:zone]}.")

      firewalld.api.remove_interface(original[name], original[name][:zone])
    end

    # Convenience method for change an interface to its current firewalld zone
    def change_interface(name)
      zone = current.fetch(name, {}).fetch(:zone, "")
      if zone.empty?
        remove_interface(name) if original[name]
      else
        log.info("Changing interface #{name} to zone #{zone}")
        firewalld.api.change_interface(zone, name)
      end
    end
  end
end
