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

require "y2remote/dialogs/remote"

module Y2Remote
  module Clients
    class Remote
      include Yast::Logger
      include Yast::I18n
      include Yast::UIShortcuts

      def initialize
        Yast.import "Label"
        Yast.import "Wizard"
        Yast.import "Report"
        Yast.import "SuSEFirewall"

        Yast.import "CommandLine"
        Yast.import "RichText"
        Yast.import "UI"

        textdomain "network"
      end

      def remote
        @remote = Y2Remote::Remote.instance
      end

      def run
        log.info("----------------------------------------")
        log.info("Remote client started")

        remote.read
        Yast::SuSEFirewall.Read

        ret = Y2Remote::Dialogs::Remote.new.run

        Yast::Wizard.CreateDialog
        Yast::Wizard.SetDesktopTitleAndIcon("remote")
        Yast::Wizard.SetNextButton(:next, Yast::Label.FinishButton)

        remote.write if ret == :next

        Yast::Wizard.CloseDialog

        log.info("----------------------------------------")
        log.info("Remote client finished")

        ret
      end
    end
  end
end
