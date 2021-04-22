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
  # This class is responsible for reading the configuration from the system
  #
  # It implements a {#config} method which returns a configuration object
  # containing the information from the corresponding backend.
  #
  # It is expect that a configuration reader exists for each supported backend
  # by inheriting from this class.
  class ConfigReader
    include Yast::Logger

    class << self
      # Returns a configuration reader for a given source
      #
      # @param source [Symbol] Source name (e.g., :wicked)
      # @param opts  [Array<Object>] Reader options
      # @return [Y2Network::Autoinst::ConfigReader,Y2Network::Wicked::ConfigReader]
      def for(source, *opts)
        require "y2network/#{source}/config_reader"
        modname = source.to_s.split("_").map(&:capitalize).join
        klass = Y2Network.const_get("#{modname}::ConfigReader")
        klass.new(*opts)
      end
    end

    def initialize(_opts = {}); end

    # Returns the configuration from the given backend
    #
    # @return [Y2Network::ReadingResult] Network configuration
    # @raise NotImplementedError
    def read
      raise NotImplementedError
    end
  end
end
