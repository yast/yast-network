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
  # Base class for startmode. It allows to create new one according to name or anlist all.
  # Its child have to define `to_human_string` method and possibly its own specialized attributes.
  # TODO: as backends differs, we probably also need to have flag there to which backends mode exists
  class Startmode
    include Yast::Logger

    attr_reader :name
    alias_method :to_s, :name

    def initialize(name)
      @name = name
    end

    # gets new instance of startmode for given type and its params
    def self.create(name)
      # avoid circular dependencies
      require "y2network/startmodes"
      Startmodes.const_get(name.capitalize).new
    rescue NameError => e
      log.error "Invalid startmode #{e.inspect}"
      nil
    end

    def self.all
      require "y2network/startmodes"
      Startmodes.constants.map { |c| Startmodes.const_get(c).new }
    end

    def ==(other)
      name == other.name
    end
  end
end
