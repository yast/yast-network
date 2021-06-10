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
require "uri"

module Yast
  class InstallInfConvertor
    include Singleton
    include Logger
    include Yast # for path shortcuts
    include I18n # for textdomain

    # Class for accessing /etc/install.inf.
    # See http://en.opensuse.org/SDB:Linuxrc_install.inf
    class InstallInf
      INSTALL_INF = Path.new(".etc.install_inf")

      def self.[](item)
        SCR.Read(INSTALL_INF + Path.new(".#{item}")).to_s
      end
    end

    def initialize
      Yast.import "DNS"
      Yast.import "IP"
      Yast.import "Proxy"
    end

    def write_netconfig
      write_global_netconfig
    end

  private

    # create all network files except ifcfg and hwcfg
    # directly to installed system
    def write_global_netconfig
      # create hostname
      write_hostname

      # create proxy sysconfig file
      write_proxy

      nil
    end

    def hostname
      hostname = InstallInf["Hostname"].to_s

      # do not have numeric hostname, #152218
      return "" if hostname.empty? || IP.Check(hostname)

      hostname
    end

    def write_hostname
      return false if hostname.empty?

      log.info("Write HOSTNAME: #{hostname}")
      SCR.Write(path(".target.string"), DNSClass::HOSTNAME_PATH, hostname)
    end

    def write_proxy
      # ProxyURL format: scheme://user:password@server:port
      proxyUrl = InstallInf["ProxyURL"].to_s

      return false if proxyUrl.empty?

      Proxy.Read
      ex = Proxy.Export

      proxy = URI(proxyUrl)
      proxyProto = proxy.scheme

      # save user name and password separately
      ex["proxy_user"] = proxy.user
      proxy.user = nil
      ex["proxy_password"] = proxy.password
      proxy.password = nil
      ex["#{proxyProto}_proxy"] = proxy.to_s
      # Use the proxy also for https and ftp
      if proxyProto == "http"
        ex["https_proxy"] = proxy.to_s
        ex["ftp_proxy"] = proxy.to_s
      end
      ex["enabled"] = true
      log.info "Writing proxy settings: #{proxyProto}_proxy = '#{proxy}'"
      log.debug "Writing proxy settings: #{ex}"

      Proxy.Import(ex)
      Proxy.Write
    end
  end
end
