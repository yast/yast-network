# encoding: utf-8

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
require "y2network/errors"

module Y2Network
  class ReadingResult
    attr_reader :config, :errors

    # Represents a reading operation result
    #
    # @fixme does it make sense when writing changes?
    #
    # @param config [Config] Read configuration
    # @param errors [Errors::List] Errors list
    def initialize(config, errors = Errors::List.new)
      @config = config
      @errors = errors
    end

    # Determines whether there is some error
    #
    # @return [Boolean]
    def errors?
      errors.any?
    end

    # Generates a new result containing the updated config and the full list of errors
    #
    # @param other [ReadingResult] Result to merge
    # @return [ReadingResult]
    def merge(other)
      ReadingResult.new(other.config, errors + other.errors)
    end
  end
end
