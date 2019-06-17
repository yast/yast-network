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

module Y2Network
  # This class represents the interface types which are supported.
  #
  # Constants may be defined using the {define_type} method.
  class InterfaceType
    extend Yast::I18n
    include Yast::I18n

    class << self
      # @param const_name [String] Constant name
      # @param name       [String] Type name ("Ethernet", "Wireless", etc.)
      def define_type(const_name, name)
        const_set(const_name, new(name))
      end
    end

    # @return [String] Return's type name
    attr_reader :name

    # Constructor
    #
    # @param name [String] Type name
    def initialize(name)
      @name = name
    end

    # Returns the translated name
    #
    # @return [String]
    def to_human_string
      _(name)
    end

    # Define types constants
    define_type "ETHERNET", N_("Ethernet")
    define_type "WIRELESS", N_("Wireless")
  end
end
