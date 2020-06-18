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

module Y2Network
  # This class is the base class for the different network backends and also
  # responsible of listing the supported ones.
  class Backend
    include Yast::I18n

    # @return [Symbol] backend id
    attr_reader :id

    # Constructor
    #
    # @param id [Symbol]
    def initialize(id)
      textdomain "network"
      Yast.import "NetworkService"

      @id = id
    end

    # Return the backend short name
    #
    # @return [String]
    def name
      id.to_s
    end

    def ==(other)
      return false unless other

      id == other.id
    end

    alias_method :eql?, :==

    # Return the translated backend label
    #
    # @return [String]
    def label
      raise NotImplementedError
    end

    alias_method :to_s, :name

    # Return all the supported backends
    #
    # @return [Array<Backend>]
    def self.all
      require "y2network/backends"
      @all ||= Backends.constants.map { |c| Backends.const_get(c).new }
    end

    # Return all the supported and installed backends
    #
    # @return [Array<Backend>]
    def self.available
      all.select(&:available?)
    end

    # Return the backend with the given id when supported
    #
    # @param id [Symbol] the backend id to be find
    # @return [Backend, nil]
    def self.by_id(id)
      all.find { |b| b.id == id }
    end

    # Return whether the backend is available or not
    #
    # @return [Boolean]
    def available?
      Yast::NetworkService.is_backend_available(id)
    end
  end
end
