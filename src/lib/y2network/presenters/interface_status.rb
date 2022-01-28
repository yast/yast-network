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
Yast.import "HTML"
Yast.import "NetHwDetection"

module Y2Network
  module Presenters
    # Mixin that provide status info about interface `status_info(config)`
    module InterfaceStatus
      include Yast::I18n
      # @param config [ConnectionConfig::Base]
      # @return [String] status information
      def status_info(config)
        textdomain "network"

        case config.bootproto
        when BootProtocol::STATIC
          return Yast::HTML.Colorize(_("Configured without an address"), "red") if !config.ip

          ip = config.ip.address.to_s
          host = Yast::NetHwDetection.ResolveIP(config.ip.address.address.to_s)
          addr = ip
          addr << "(#{host})" if host && !host.empty?
          if config.ip.remote_address
            # TRANSLATORS %{local} is local address and %{remote} is remote address
            format(
              _("Configured with address %{local} (remote %{remote})"),
              local:  addr,
              remote: config.ip.remote_address.to_s
            )
          else
            # TRANSLATORS %s is address
            format(_("Configured with address %s"), addr)
          end
        when BootProtocol::NONE
          _("Do not assign (e.g. if included in a bond or bridge)")
        else
          # TODO: maybe human name for boot protocols?
          format(_("Configured with %s"), config.bootproto.name)
        end
      end
    end
  end
end
