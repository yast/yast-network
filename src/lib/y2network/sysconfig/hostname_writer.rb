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
require "yast2/execute"
require "y2network/sysconfig/interface_file"

module Y2Network
  module Sysconfig
    # This class writes Hostname configuration settings.
    class HostnameWriter
      include Yast::Logger

      # Writes Hostname configuration
      #
      # @param hostname [Y2Network::Hostname] Hostname configuration
      # @param old_hostname [Y2Network::Hostname] Old Hostname configuration
      def write(hostname, old_hostname)
        return if old_hostname && hostname == old_hostname

        update_sysconfig_dhcp(hostname, old_hostname)
        update_hostname(hostname) if hostname.save_hostname?
      end

    private

      # @return [String] Hostname executable
      HOSTNAME_PATH = "/etc/hostname".freeze
      # @return [String] Sendmail update script (included in "sendmail" package)
      SENDMAIL_UPDATE_PATH = "/usr/lib/sendmail.d/update".freeze

      # @param hostname [Y2Network::Hostname] Hostname configuration
      # @param old_hostname [Y2Network::Hostname] Old Hostname configuration
      def update_sysconfig_dhcp(hostname, old_hostname)
        if old_hostname.nil? || old_hostname.dhcp_hostname == hostname.dhcp_hostname
          log.info("No update for /etc/sysconfig/network/dhcp")
          return
        end

        Yast::SCR.Write(
          Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"),
          (hostname.dhcp_hostname == :any) ? "yes" : "no"
        )
        Yast::SCR.Write(Yast::Path.new(".sysconfig.network.dhcp"), nil)

        # Clean-up values from ifcfg-* values
        Y2Network::Sysconfig::InterfaceFile.all.each do |file|
          value = (file.interface == hostname.dhcp_hostname) ? "yes" : nil
          file.load
          next if file.dhclient_set_hostname == value

          file.dhclient_set_hostname = value
          file.save
        end
      end

      # Sets the hostname
      #
      # @param hostname [Y2Network::Hostname] Hostname configuration
      def update_hostname(hostname)
        # 1) when user asked for ereasing hostname from /etc/hostname, we keep runtime as it is
        # 2) we will write whatever user wants even FQDN - no changes under the hood
        Yast::Execute.on_target!("/usr/bin/hostname", hostname.static) if !hostname.static.empty?
        Yast::SCR.Write(Yast::Path.new(".target.string"), HOSTNAME_PATH, hostname.static.empty? ? hostname.static : "#{hostname.static}\n")
      end
    end
  end
end
