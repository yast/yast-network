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

    # @return [Boolean] network service to be used after the installation
    attr_accessor :selected_backend

    # Constructor
    def initialize
      Yast.import "Arch"
      Yast.import "ProductFeatures"
      Yast.import "Package"
      Yast.import "PackagesProposal"

      @selected_backend = nil
    end

    def current_backend
      selected_backend || default_backend
    end

    def default_backend
      default = use_network_manager? ? :network_manager : :wicked
      log.info "The default backend is: #{default}"
      default
    end

    # Adds the NetworkManager package to the {Yast::PackagesProposal} and sets
    # NetworkManager as the backend to be used
    def enable_network_manager!
      log.info "Enabling NetworkManager"
      self.selected_backend = :network_manager
      refresh_packages

      selected_backend
    end

    # Add the wicked package to the {Yast::PackagesProposal} and sets wicked
    # as the backend to be used
    def enable_wicked!
      log.info "Enabling Wicked"
      self.selected_backend = :wicked
      refresh_packages

      selected_backend
    end

    def refresh_packages
      if current_backend == :network_manager
        Yast::PackagesProposal.AddResolvables("network", :package, ["NetworkManager"])
        Yast::PackagesProposal.RemoveResolvables("network", :package, ["wicked"])
      else
        Yast::PackagesProposal.AddResolvables("network", :package, ["wicked"])
        Yast::PackagesProposal.RemoveResolvables("network", :package, ["NetworkManager"])
      end
    end

    # Convenience method to obtain whether the NetworkManager package is
    # available or not.
    #
    # @return [Boolean] false if no package available, true otherwise
    def network_manager_available?
      p = Y2Packager::Package.find("NetworkManager").first
      if p.nil?
        log.info("The NetworkManager package is not available")
        return false
      end
      log.info("The NetworkManager package status: #{p.status}")
      true
    end

    # Propose the network service to be use at the end of the installation
    # depending on the backend selected during the proposal and the packages
    # installed
    def network_service
      case current_backend
      when :network_manager
        network_manager_installed? ? :network_manager : :wicked
      else
        :wicked
      end
    end

    class << self
      # Singleton instance
      def instance
        @instance ||= create_instance
      end

      # Enforce a new clean instance
      def create_instance
        @instance = new
      end

      # Make sure only .instance and .create_instance can be used to
      # create objects
      private :new, :allocate
    end

  private

    # Convenienve method that verify if Network Manager should be used or not
    # according to the control file defaults and package availability.
    #
    # @return [Boolean] true if should be used; false otherwise
    def use_network_manager?
      return false unless network_manager_available?

      network_manager_default?
    end

    # Convenience method to determine if the NM package is installed or not
    #
    # @return [Boolean] true if NetworkManager is installed; false otherwise
    def network_manager_installed?
      Yast::Package.Installed("NetworkManager")
    end

    # Determine whether NetworkManager should be selected by default according
    # to the product control file
    #
    # @return [Boolean] true if NM should be enabled; false otherwise
    def network_manager_default?
      case Yast::ProductFeatures.GetStringFeature("network", "network_manager")
      when ""
        # compatibility: use the boolean feature
        # (defaults to false)
        Yast::ProductFeatures.GetBooleanFeature("network", "network_manager_is_default")
      when "always"
        true
      when "laptop"
        laptop = Yast::Arch.is_laptop
        log.info("Is a laptop: #{laptop}")
        laptop
      end
    end
  end
end
