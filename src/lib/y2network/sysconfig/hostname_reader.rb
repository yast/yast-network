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
require "y2network/sysconfig/interface_file"
require "y2network/hostname"
require "network/wicked"

Yast.import "Hostname"
Yast.import "IP"
Yast.import "Stage"
Yast.import "NetHwDetection"

module Y2Network
  module Sysconfig
    # This class is responsible for reading the hostname
    #
    # Depending on different circunstamces, the hostname can be read from different places (from a
    # simple call to `/usr/bin/hostname` to the `/etc/install.inf` during installation).
    #
    # @example Read hostname
    #   Y2Network::HostnameReader.new.hostname #=> "foo"
    class HostnameReader
      include Yast::Logger
      include Yast::Wicked

      # Return configuration from sysconfig files
      #
      # @return [Y2Network::Hostname] Hostname configuration
      def config
        transient_hostname = if Yast::Stage.initial
          hostname_from_dhcp
        else
          hostname_from_resolver
        end

        Y2Network::Hostname.new(
          installer:     hostname_from_install_inf,
          static:        hostname_from_system,
          transient:     transient_hostname,
          dhcp_hostname: dhcp_hostname
        )
      end

      # Returns whether the hostname should be taken from DHCP
      #
      # @return [String,:any,:none] Interface to set the hostname based on DHCP settings;
      #   :any for any interface; :none for ignoring the hostname assigned via DHCP
      def dhcp_hostname
        value = Yast::SCR.Read(Yast::Path.new(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"))
        return :any if value == "yes"

        files = InterfaceFile.all
        file = files.find do |f|
          f.load
          f.dhclient_set_hostname == "yes"
        end
        file ? file.interface : :none
      end

      # Reads the hostname from the /etc/install.inf file
      #
      # @return [String,nil] Hostname
      def hostname_from_install_inf
        install_inf_hostname = Yast::SCR.Read(Yast::Path.new(".etc.install_inf.Hostname")) || ""
        log.info("Got #{install_inf_hostname} from install.inf")

        return nil if install_inf_hostname.empty?

        # if the name is actually IP, try to resolve it (bnc#556613, bnc#435649)
        if Yast::IP.Check(install_inf_hostname)
          fqdn = Yast::NetHwDetection.ResolveIP(install_inf_hostname)
          log.info("Got #{fqdn} after resolving IP from install.inf")
        else
          fqdn = install_inf_hostname
        end

        host, _domain = *Yast::Hostname.SplitFQ(fqdn)
        return nil if host.nil? || host.empty?

        host
      end

      # Reads the (transient) hostname known to the resolver
      #
      # @return [String, nil] Hostname or nil if transient hostname is not known
      def hostname_from_resolver
        Yast::Execute.on_target!("/usr/bin/hostname", "--fqdn", stdout: :capture).strip
      rescue Cheetah::ExecutionFailed
        nil
      end

      # Reads the system (local) hostname
      #
      # @return [String, nil] Hostname
      def hostname_from_system
        Yast::Execute.on_target!("/usr/bin/hostname", stdout: :capture).strip
      rescue Cheetah::ExecutionFailed
        name = Yast::SCR.Read(Yast::Path.new(".target.string"), "/etc/hostname").to_s.strip
        name.empty? ? nil : name
      end

      # Queries for hostname obtained as part of dhcp configuration
      #
      # @return [String, nil] Hostname
      def hostname_from_dhcp
        # We currently cannot use connections for getting only dhcp aware configurations here
        # bcs this can be called during Y2Network::Config initialization and this is
        # acceptable replacement for this case.
        ifaces = Sysconfig::InterfaceFile.all.map(&:interface)
        dhcp_hostname = ifaces.map { |i| parse_hostname(i) }.compact.first

        log.info("Hostname obtained from DHCP: #{dhcp_hostname}")

        dhcp_hostname
      end
    end
  end
end
