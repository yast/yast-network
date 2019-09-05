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

Yast.import "FileUtils"
Yast.import "Hostname"
Yast.import "IP"
Yast.import "Mode"
Yast.import "NetHwDetection"

module Y2Network
  # This class is responsible for reading the hostname
  #
  # Depending on different circunstamces, the hostname can be read from different places (from a
  # simple call to `/bin/hostname` to the `/etc/install.inf` during installation).
  #
  # @example Read hostname
  #   Y2Network::HostnameReader.new.hostname #=> "foo"
  class HostnameReader
    include Yast::Logger

    # Returns the hostname
    #
    # @return [String]
    def hostname
      if (Yast::Mode.installation || Yast::Mode.autoinst) && Yast::FileUtils.Exists("/etc/install.inf")
        fqdn = hostname_from_install_inf
      end

      return hostname_from_system if fqdn.nil? || fqdn.empty?
      host, _domain = *Yast::Hostname.SplitFQ(fqdn)
      host
    end

    # Reads the hostname from the /etc/install.inf file
    #
    # @return [String] Hostname
    def hostname_from_install_inf
      install_inf_hostname = Yast::SCR.Read(Yast::Path.new(".etc.install_inf.Hostname")) || ""
      log.info("Got #{install_inf_hostname} from install.inf")

      return "" if install_inf_hostname.empty?

      # if the name is actually IP, try to resolve it (bnc#556613, bnc#435649)
      if Yast::IP.Check(install_inf_hostname)
        fqdn = Yast::NetHwDetection.ResolveIP(install_inf_hostname)
        log.info("Got #{fqdn} after resolving IP from install.inf")
      else
        fqdn = install_inf_hostname
      end

      fqdn
    end

    # Reads the hostname from the underlying system
    #
    # @return [String] Hostname
    def hostname_from_system
      Yast::Execute.stdout.on_target!("/bin/hostname").strip
    end
  end
end
