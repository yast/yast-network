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
module Y2Network
  # This module contains a set of classes to read the network configuration from the system
  #
  # For the time being, only the wicked via its backward compatibility with sysconfig
  # is available in ({Y2Network::ConfigBuilder::Sysconfig}) builder
  module ConfigBuilder
    # Config builder for a given source
    #
    # @param source [Symbol] Source name (e.g., :sysconfig)
    # @param opts   [Hash] Builder options
    # @return [#config] Configuration builder from {Y2Network::ConfigBuilder}
    def self.for(source, opts = {})
      require "y2network/config_builder/#{source}"
      name = source.to_s.split("_").map(&:capitalize).join
      klass = const_get(name)
      klass.new(opts)
    end
  end
end
