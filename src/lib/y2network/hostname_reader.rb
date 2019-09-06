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
  # simple call to `/usr/bin/hostname` to the `/etc/install.inf` during installation).
  #
  # @example Read hostname
  #   Y2Network::HostnameReader.new.hostname #=> "foo"
  class HostnameReader
    include Yast::Logger

    # Returns the hostname
    #
    # @note If the hostname cannot be determined, generate a random one.
    #
    # @return [String]
    def hostname
      if (Yast::Mode.installation || Yast::Mode.autoinst) && Yast::FileUtils.Exists("/etc/install.inf")
        fqdn = hostname_from_install_inf
      end

      fqdn || hostname_from_system || random_hostname
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
      host.empty? ? nil : host
    end

    # Reads the hostname from the underlying system
    #
    # @return [String] Hostname
    def hostname_from_system
      Yast::Execute.on_target!("/usr/bin/hostname", "--fqdn", stdout: :capture)
    rescue Cheetah::ExecutionFailed
      name = Yast::SCR.Read(Yast::Path.new(".target.string"), "/etc/hostname").to_s.strip
      name.empty? ? nil : name
    end

    # @return [Array<String>] Valid chars to be used in the random part of a hostname
    HOSTNAME_CHARS = (("a".."z").to_a + ("0".."9").to_a).freeze
    private_constant :HOSTNAME_CHARS

    # Returns a random hostname
    #
    # The idea is to use a name like this as fallback.
    #
    # @return [String]
    def random_hostname
      suffix = HOSTNAME_CHARS.sample(4).join
      "linux-#{suffix}"
    end
  end
end
