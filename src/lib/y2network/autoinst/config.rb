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
  module Autoinst
    # This class is responsible of storing network settings that are only
    # relevant to the autoinstallation proccess.
    class Config
      # @return [Boolean] controls whether the network configuration should be
      #   run before the proposal
      attr_accessor :before_proposal
      # @return [Boolean] controls whether the network should be restarted
      #   immediately after write or not
      attr_accessor :start_immediately
      # @return [Boolean] controls whether the configuration done during the
      #   installation should be copied to the target system at the end
      attr_accessor :keep_install_network
      # @return [Integer]
      attr_accessor :ip_check_timeout

      # Constructor
      #
      # @param opts [Hash]
      # @option opts [Boolean] :before_proposal
      # @option opts [Boolean] :start_immediately
      # @option opts [Boolean] :keep_install_network
      # @option opts [Integer] :ip_check_timetout
      def initialize(opts = {})
        @before_proposal = opts.fetch(:before_proposal, false)
        @start_immediately = opts.fetch(:start_immediately, false)
        @keep_install_network = opts.fetch(:keep_install_network, true)
        @ip_check_timeout = opts.fetch(:ip_check_timeout, -1)
      end

      # Return whether the network should be copied at the end
      #
      # @return [Boolean]
      def copy_network?
        keep_install_network || before_proposal
      end
    end
  end
end
