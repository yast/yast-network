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

module Y2Network
  module Sequences
    # The responsibility of this class is to drive workflow for sequence of dialogs.
    #
    # In this case, allowed operations for interface are, 'add' for adding a new interface,
    # 'edit' for editing an existing device / interface or 'init_s390' for s390
    # initialization which needs specific activation before using it.
    #
    # TODO: use UI::Sequence, but it needs also another object dialogs e.g for wifi
    class Interface
      include Yast::I18n
      include Yast::Logger

      def initialize
        Yast.include self, "network/lan/wizards.rb"
      end

      # Starts sequence for adding new interface and configuring it
      def add(default: nil)
        res = Y2Network::Dialogs::AddInterface.run(default: default)
        return unless res

        sym = edit(res)
        log.info "result of following edit #{sym.inspect}"
        sym = add(default: res.type) if sym == :back

        sym
      end

      # Starts sequence for editing configuration of interface
      def edit(builder)
        NetworkCardSequence("edit", builder: builder)
      end

      # Starts sequence for activating s390 device and configuring it
      def init_s390(builder)
        NetworkCardSequence("init_s390", builder: builder)
      end
    end
  end
end
