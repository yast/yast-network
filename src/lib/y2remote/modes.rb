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
require "y2remote/modes/vnc.rb"
require "y2remote/modes/manager.rb"
require "y2remote/modes/web.rb"

module Y2Remote
  class Modes
    MODES = [VNC, Manager, Web].freeze

    class << self
      def all
        MODES
      end

      def running_modes
        all.select { |m| m.instance.enabled? }.map(&:instance)
      end

      def restart_modes(enable_modes = [])
        all.each do |mode|
          enable_modes.include?(mode.instance) ? mode.instance.restart! : mode.instance.stop!
        end
      end

      def update_status(enable_modes = [])
        all.each do |mode|
          enable_modes.include?(mode.instance) ? mode.instance.enable! : mode.instance.disable!
        end
      end
    end
  end
end
