# encoding: utf-8
#
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
require "y2packager/package"

module Y2Network
  # Class that stores the proposal settings for network during installation.
  class ProposalSettings
    include Yast::Logger
    include Yast::I18n

    # [Boolean] network service to be used after the installation
    attr_accessor :backend

    # Constructor
    def initialize
      Yast.import "PackagesProposal"
      Yast.import "Lan"

      @backend = use_network_manager? ? :network_manager : :wicked
    end

    # Services

    # Add the NetworkManager package to be installed and sets NetworkManager as
    # the backend to be used
    def enable_network_manager!
      Yast::PackagesProposal.AddResolvables("network", :package, ["NetworkManager"])
      Yast::PackagesProposal.RemoveResolvables("network", :package, ["wicked"])

      log.info "Enabling NetworkManager"
      self.backend = :network_manager
    end

    def enable_wicked!
      Yast::PackagesProposal.AddResolvables("network", :package, ["wicked"])
      Yast::PackagesProposal.RemoveResolvables("network", :package, ["NetworkManager"])

      log.info "Enabling Wicked"
      self.backend = :wicked
    end

    class << self
      # Singleton instance
      def instance
        create_instance unless @instance
        @instance
      end

      # Enforce a new clean instance
      def create_instance
        @instance = new
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end

    def network_manager_available?
      p = Y2Packager::Package.find("NetworkManager").first
      return false if p.nil?
      log.info("The NetworkManager package status: #{p.status}")
      true
    end

  private

    def use_network_manager?
      return false unless network_manager_available?

      Yast::Lan.UseNetworkManager
    end
  end
end
