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
require "y2network/wicked/connection_config_reader"
require "forwardable"

module Y2Network
  module Errors
    class List
      include Enumerable
      extend Forwardable

      def_delegators :@items, :each, :empty?, :<<

      # Constructor
      #
      # @param [Array<Error>] List of errors
      def initialize(items = [])
        @items = items
      end

      # Concats two lists into a new one
      #
      # @return [List]
      def +(other)
        List.new(@items + other.items)
      end
    end

    class Base
      include Yast::I18n

      # @return [Symbol]
      def severity
        raise NotImplementedError
      end

      # @return [String]
      def message
        raise NotImplementedError
      end
    end

    # Represents an invalid value
    class InvalidValue < Base
      attr_reader :subject
      attr_reader :value
      attr_reader :fallback

      def initialize(subject, value, fallback = nil)
        @subject = subject
        @value = value
        @fallback = fallback
      end

      def severity
        :warn
      end

      def message
        msg = format(_("Invalid value '%{value}' for '%{subject}'."), value: value, subject: subject)
        if fallback
          msg << " " + format(_("Using '%{fallback}' instead."), fallback: fallback)
        end
        msg
      end
    end

    # Represents an invalid value
    class MissingValue < Base
      attr_reader :subject
      attr_reader :fallback

      def initialize(subject, fallback = nil)
        @subject = subject
        @fallback = fallback
      end

      def severity
        :warn
      end

      def message
        msg = format(_("Missing '%{subject}'."), subject: subject)
        if fallback
          msg << " " + format(_("Using '%{fallback}' instead."), fallback: fallback)
        end
        msg
      end
    end

    # Formats a list of error to be presented to the user
    class Presenter
      include Yast::I18n

      attr_reader :list

      def initialize(list)
        @list = list
      end

      def to_s
        lines = list.map do |error|
          "* #{error.severity}: #{error.message}"
        end
        message + lines.join("\n")
      end

      def to_html
        Yast::HTML.Para(message) + Yast::HTML.List(list.map(&:message))
      end

      def message
        _("The following errors were detected while reading the network configuration:")
      end
    end
  end
end
