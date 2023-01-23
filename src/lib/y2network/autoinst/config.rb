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
      # @return [Boolean] controls whether a bridge configuration for
      #   virtualization network should be proposed or not
      attr_accessor :virt_bridge_proposal
      # @return [Boolean] returns whether the network is managed by NM or not
      attr_accessor :managed
      # @return [Symbol] backend id
      attr_accessor :backend

      # Constructor
      #
      # @param opts [Hash]
      # @option opts [Boolean] :before_proposal
      # @option opts [Boolean] :start_immediately
      # @option opts [Boolean] :keep_install_network
      # @option opts [Integer] :ip_check_timetout
      # @option opts [Boolean] :virt_bridge_proposal
      # @options opts [Boolean] :managed
      # @options opts [String, Symbol] :backend
      def initialize(opts = {})
        ay_options = opts.reject { |_k, v| v.nil? }

        @before_proposal = ay_options.fetch(:before_proposal, false)
        @start_immediately = ay_options.fetch(:start_immediately, true)
        @keep_install_network = ay_options.fetch(:keep_install_network, true)
        @ip_check_timeout = ay_options.fetch(:ip_check_timeout, -1)
        @virt_bridge_proposal = ay_options.fetch(:virt_bridge_proposal, true)
        @managed              = ay_options[:managed]
        @backend              = ay_options[:backend]&.to_sym
      end

      # Return whether the network should be copied at the end
      #
      # @return [Boolean]
      def copy_network?
        keep_install_network || before_proposal
      end

      # Explicitly selected backend according to the AY options given
      #
      # @return [Symbol, nil]
      def selected_backend
        return backend.to_sym unless [nil, ""].include?(backend)
        return if managed.nil?

        managed ? :network_manager : :wicked
      end
    end
  end
end
