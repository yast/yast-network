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
require "y2remote/modes/vnc.rb"
require "y2remote/modes/manager.rb"
require "y2remote/modes/web.rb"

module Y2Remote
  module Modes
    MODES = [VNC, Manager, Web].freeze

    # Return a list with all the available Y2Remote::Remote::Base subclases
    #
    # @return [Array<Y2Remote::Modes::Base>] list of available modes
    def self.all
      MODES
    end

    # Return a list with all the enabled Y2Remote::Modes::Base instances.
    #
    # @return [Array<Y2Remote::Modes::Base>] list of enabled modes
    def self.running_modes
      all.select { |m| m.instance.enabled? }.map(&:instance)
    end

    # Restart all the given list of Y2Remote::Modes::Base instances and stop
    # the rest.
    #
    # @param enable_modes [Array<Y2Remote::Modes::Base>] list of modes to be restarted, the
    # rest will be stopped
    def self.restart_modes(enable_modes = [])
      # There are conflicts between modes. Therefore we have to stop first the
      # disabled ones.
      all.each { |mc| mc.instance.stop! unless enable_modes.include?(mc.instance) }

      enable_modes.each(&:restart!)
    end

    # Enable all the given list of Y2Remote::Modes::Base instances and
    # disable the rest.
    #
    # @param enable_modes [Array<Y2Remote::Modes::Base>] list of modes to be enabled; the
    # rest will be disable
    def self.update_status(enable_modes = [])
      all.each do |mode|
        enable_modes.include?(mode.instance) ? mode.instance.enable! : mode.instance.disable!
      end
    end
  end
end
