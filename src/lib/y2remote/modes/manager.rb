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

require "y2remote/modes/base"

module Y2Remote
  module Modes
    # This class is reponsible of vncmanager service management
    class Manager < Base
      # [String] Service name
      SERVICE  = "vncmanager".freeze
      # [Array<String>] Packages needed by the service
      PACKAGES = ["vncmanager"].freeze

      # Return the list of the packages needed by the service
      #
      # @return [Array<String>] list of required packages
      def required_packages
        PACKAGES
      end

      # Convenience method with return whether the service is enabled
      #
      # @return [Boolean] true if the service is enabled; false otherwise
      def enabled?
        Yast::Service.Enabled(SERVICE)
      end

      # Convenience method to stop the service. It return false if the service
      # is not installed.
      #
      # @return [Boolean] return false if the service is not installed or not
      # stopped; true if stopped with success
      def stop
        return false unless installed?

        Yast::Service.Stop(SERVICE)
      end

      # Convenience method to stop the service reporting an error in case of
      # failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the service is not installed or not
      # stopped; true if stopped with success
      def stop!
        return false unless installed?

        if !Yast::Service.Stop(SERVICE)
          Yast::Report.Error(Yast::Message.CannotStopService(SERVICE))
          return false
        end

        true
      end

      # Convenience method to restart the service. It return false if the
      # service is not installed.
      #
      # @return [Boolean] return false if the service is not installed or not
      # restarted; true if restarted with success
      def restart
        return false unless installed?
        Yast::Service.Restart(SERVICE)
      end

      # Convenience method to restart the service reporting an error in case
      # of failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the service is not installed or not
      # restarted; true if restarted with success
      def restart!
        return false unless installed?

        if !Yast::Service.Restart(SERVICE)
          Yast::Report.Error(Yast::Message.CannotRestartService(SERVICE))
          return false
        end

        true
      end

      # Convenience method to enable the service reporting an error in case of
      # failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the service is not installed or not
      # enabled; true if enabled with success
      def enable!
        return false unless installed?

        if !Yast::Service.Enable(SERVICE)
          Yast::Report.Error(
            _("Enabling service %{service} has failed") % { service: SERVICE }
          )
          return false
        end

        true
      end

      # Convenience method to disable the service reporting an error in case of
      # failure. It return false if the service is not installed.
      #
      # @return [Boolean] return false if the service is not installed or not
      # disabled; true if disabled with success
      def disable!
        return false unless installed?

        if !Yast::Service.Disable(SERVICE)
          Yast::Report.Error(
            _("Disabling service %{service} has failed") % { service: SERVICE }
          )
          return false
        end

        true
      end
    end
  end
end
