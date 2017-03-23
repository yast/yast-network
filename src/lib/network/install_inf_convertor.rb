require "yast"
require "uri"

module Yast
  class InstallInfConvertor
    include Singleton
    include Logger
    include Yast # for path shortcuts
    include I18n # for textdomain

    BASH_PATH = Path.new(".target.bash")

    # Class for accessing /etc/install.inf.
    # See http://en.opensuse.org/SDB:Linuxrc_install.inf
    class InstallInf
      INSTALL_INF = Path.new(".etc.install_inf")

      def self.[](item)
        SCR.Read(INSTALL_INF + Path.new(".#{item}")).to_s
      end
    end

    def initialize
      Yast.import "Hostname"
      Yast.import "DNS"
      Yast.import "IP"
      Yast.import "NetworkInterfaces"
      Yast.import "FileUtils"
      Yast.import "Netmask"
      Yast.import "Proxy"
      Yast.import "String"
      Yast.import "Arch"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/complex.rb"
    end

    def write_netconfig
      write_global_netconfig
    end

    # Reports if user asked for using biosdevname pernament device names
    def AllowUdevModify
      /biosdevname=1/ !~ InstallInf["Cmdline"]
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
      ex["enabled"] = true
      log.info "Writing proxy settings: #{proxyProto}_proxy = '#{proxy}'"
      log.debug "Writing proxy settings: #{ex}"

      Proxy.Import(ex)
      Proxy.Write
    end

    def stdout_of(command)
      SCR.Execute(path(".target.bash_output"), command)["stdout"].to_s
    end
  end
end
