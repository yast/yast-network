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
require "y2network/hostname"
require "y2network/sysconfig/hostname_reader"

module Y2Network
  module Autoinst
    # This class is responsible of importing hostname setup from the AutoYast dns section
    class HostnameReader
      # @return [AutoinstProfile::DNSSection]
      attr_reader :section

      # NOTE: for historical reasons DNS section contains even hostname
      # @param section [AutoinstProfile::DNSSection]
      def initialize(section)
        @section = section
      end

      # Creates a new {Hostname} config from the imported profile dns section
      #
      # @return [Hostname] the imported {Hostname} config
      def config
        Y2Network::Hostname.new(
          dhcp_hostname: section.dhcp_hostname ? :any : :none,
          static:        static_hostname,
          installer:     section.hostname
        )
      end

    private

      # Returns the current static_hostname
      #
      # @return [String]
      def static_hostname
        Y2Network::Sysconfig::HostnameReader.new.static_hostname
      end
    end
  end
end
