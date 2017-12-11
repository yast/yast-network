# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2017 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"

module Y2Remote
  # Class to handle the different remote running modes
  module Modes
    # Base class
    class Base
      include Singleton
      include Yast::Logger
      include Yast::I18n
      extend Yast::I18n

      # Construsctor
      def initialize
        Yast.import "Packages"
      end

      # Return a list of names of the required packages of the running mode
      #
      # @return [Array<String>] list of packages required by the service
      def required_packages
        []
      end

      # Return whether all the required packages have been installed or not
      #
      # @return [Boolean] true if installed; false otherwise
      def installed?
        Yast::Package.InstalledAll(required_packages)
      end
    end
  end
end
