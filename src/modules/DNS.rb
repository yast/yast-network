# encoding: utf-8

# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
# File:	modules/DNS.ycp
# Package:	Network configuration
# Summary:	Hostname and DNS data
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Manages resolv.conf and (fully qualified) hostname, also
# respecting DHCP.
require "yast"
require "shellwords"
require "y2network/sysconfig/config_writer"

module Yast
  class DNSClass < Module
    include Logger

    HOSTNAME_FILE = "hostname".freeze
    HOSTNAME_PATH = "/etc/" + HOSTNAME_FILE

    # Defines a proxy method to DNS configuration
    #
    # The idea is to keep DNS.hostname, DNS.nameservers, etc. methods
    # so they can still being used in the UI. This mechanism should
    # be removed in the future, when the widgets are adapted to the new API.
    #
    # @param name [Symbol]       Public method's name
    def self.define_config_method(name)
      define_method(name) do
        yast_dns_config.public_send(name)
      end

      define_method("#{name}=") do |value|
        yast_dns_config.public_send("#{name}=", value)
      end
    end

    define_config_method :hostname
    define_config_method :nameservers
    define_config_method :searchlist
    define_config_method :dhcp_hostname
    define_config_method :resolv_conf_policy

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Arch"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "Service"
      Yast.import "String"
      Yast.import "FileUtils"
      Yast.import "Stage"
      Yast.import "Report"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/runtime.rb"

      # Domain Name (not including the host part)
      @domain = ""

      # resolver config file location
      @resolv_conf = "/etc/resolv.conf"

      # True if DNS is already read
      @initialized = false
    end

    # Handles input as one line of getent output. Returns first hostname found
    # on the line (= canonical hostname).
    #
    # @param [String] line in /etc/hosts format
    # @return canonical hostname from given line
    def GetHostnameFromGetent(line)
      #  line is expected same format as is used in /etc/hosts without additional
      #  comments (getent removes comments from the end).
      #
      #  /etc/hosts line is formatted this way (man 5 hosts):
      #
      #      <ip address> <canonical hostname> [<alias> ...]
      #
      #  - field separators are at least one space and/or tab.
      #  - <canonical hostname>, in generic it is "a computer's unique name". In case
      #  of DNS world, <canonical hostname> is FQDN ("A" record), then <hostname> is
      #  <canonical hostname> without domain part. For example:
      #
      #      foo.example.com. IN A 1.2.3.4
      #
      #  <canonical hostname> => foo.example.com
      #  <hostname> => foo
      #
      canonical_hostname = Builtins.regexpsub(
        line,
        Builtins.sformat("^[%1]+[[:blank:]]+(.*)", IP.ValidChars),
        "\\1"
      )

      canonical_hostname = String.FirstChunk(canonical_hostname, " \t\n")
      canonical_hostname = String.CutBlanks(canonical_hostname)

      if !Hostname.CheckDomain(canonical_hostname) &&
          !Hostname.Check(canonical_hostname)
        Builtins.y2error(
          "GetHostnameFromGetent: Invalid hostname detected (%1)",
          canonical_hostname
        )
        Builtins.y2error("GetHostnameFromGetent: input params - begin")
        Builtins.y2error("%1", line)
        Builtins.y2error("GetHostnameFromGetent: input params - end")

        return ""
      end

      Builtins.y2milestone(
        "GetHostnameFromGetEnt: canonical hostname => (%1)",
        canonical_hostname
      )

      canonical_hostname
    end

    # Resolve IP to canonical hostname
    #
    # @param [String] ip given IP address
    # @return resolved canonical hostname (FQDN) for given IP or empty string in case of failure.
    def ResolveIP(ip)
      getent = SCR.Execute(path(".target.bash_output"), "/usr/bin/getent hosts #{ip.shellescape}")
      exit_code = Ops.get_integer(getent, "exit", -1)

      if exit_code != 0
        Builtins.y2error("ResolveIP: getent call failed (%1)", getent)

        return ""
      end

      GetHostnameFromGetent(Ops.get_string(getent, "stdout", ""))
    end

    def DefaultWriteHostname
      # FaTe#303875: Introduce a switch regarding 127.0.0.2 entry in /etc/hosts
      whth = ProductFeatures.GetBooleanFeature(
        "globals",
        "write_hostname_to_hosts"
      )
      Builtins.y2milestone("write_hostname_to_hosts default value: %1", whth)
      whth
    end

    # Default value for #dhcp_hostname based on ProductFeatures and Arch
    #
    # @return [Boolean] value set in features or, if none is set, false just
    #                   for laptops
    def default_dhcp_hostname
      # ProductFeatures.GetBooleanFeature returns false either if the value is
      # false or if it's missing, so let's discard the later case calling
      # ProductFeatures.GetFeature first
      feature_index = ["globals", "dhclient_set_hostname"]
      feature = ProductFeatures.GetFeature(*feature_index)
      # No value for the feature
      if feature.nil? || (feature.respond_to?(:empty?) && feature.empty?)
        !Arch.is_laptop
      else
        ProductFeatures.GetBooleanFeature(*feature_index)
      end
    end

    # Determines whether the hostname should be written to /etc/hosts
    #
    # This method stays just for compatibility reasons and it always returns `false`.
    # It should be removed when `WRITE_HOSTNAME_TO_HOSTS` related stuff is dropped.
    #
    # @return [false]
    # @see https://features.opensuse.org/308824
    def write_hostname
      false
    end

    # Reads DNS settings
    #
    # @note It reads all network settings, including DNS ones.
    def Read
      Yast::Lan.Read(:cache)
    end

    # Write new DNS and hostname settings
    # Includes Host,NetworkConfig::Write
    # @todo Update GUI
    # @return true if success
    def Write(_gui: true)
      writer = Y2Network::Sysconfig::DNSWriter.new
      writer.write(Yast::Lan.yast_config.dns, Yast::Lan.system_config.dns)
      true
    end

    # Proposes hostname if none was given
    #
    # @see Y2Network::DNS#ensure_hostname!
    def propose_hostname
      yast_dns_config.ensure_hostname!
    end

    # Check if hostname or IP address is local computer
    # Used to determine if LDAP server is local (and it should be checked if
    #  required schemes are included
    # Calls Read () function before querying any data
    # @param [String] check_host string hostname or IP address to check
    # @return [Boolean] true if hostname is local host
    # NOTE: used in yast2-nis-server, yast2-samba-server, yast2-dhcp-server
    def IsHostLocal(check_host)
      Read()
      NetworkInterfaces.Read
      dhcp_data = {}

      if Ops.greater_than(
        Builtins.size(NetworkInterfaces.Locate("BOOTPROTO", "dhcp")),
        0
      ) || dhcp_hostname
        dhcp_data = dhcp_data()
        Builtins.y2milestone("Got DHCP-configured data: %1", dhcp_data)
      end
      # FIXME: May not work properly in following situations:
      # 	- multiple addresses per interface
      #     - aliases in /etc/hosts
      # 	- IPADDR=IP/24

      # loopback interface
      return true if check_host == "127.0.0.1" || check_host == "::1"
      # localhost hostname
      if check_host == "localhost" || check_host == "localhost.localdomain"
        return true
      end

      # IPv4 address
      if IP.Check4(check_host)
        if Ops.greater_than(
          Builtins.size(NetworkInterfaces.Locate("IPADDR", check_host)),
          0
        ) ||
            Ops.get(dhcp_data, "ip", "") == check_host
          return true
        end
      # IPv6 address
      elsif IP.Check6(check_host)
        Builtins.y2debug(
          "TODO make it similar to IPv4 after other code adapted to IPv6"
        )
      # short hostname
      elsif Builtins.findfirstof(check_host, ".").nil?
        if Builtins.tolower(check_host) == Builtins.tolower(@hostname) ||
            Ops.get(dhcp_data, "hostname_short", "") == check_host
          return true
        end
      elsif Builtins.tolower(check_host) ==
          Builtins.tolower(Ops.add(Ops.add(@hostname, "."), @domain)) ||
          Ops.get(dhcp_data, "hostname_fq", "") == check_host
        return true
      end
      false
    end

    # Determines whether the DNS configuration has been modified
    #
    # @return [Boolean]
    def modified
      system_dns_config.nil? || yast_dns_config != system_dns_config
    end

  private

    # Return current IP and hostname values
    #
    # @return [Hash<String>] a map containing ip, hostname_short, and hostname_fq keys
    def dhcp_data
      {
        "ip"             => Yast::Execute.stdout.on_target!("/bin/hostname -i").strip,
        "hostname_short" => Yast::Execute.stdout.on_target!("/bin/hostname").strip,
        "hostname_fq"    => Yast::Execute.stdout.on_target!("/bin/hostname -f").strip
      }
    end

    # A constant for translating sysconfig's yes/no values into boolean
    SYSCFG_TO_BOOL = { "yes" => true, "no" => false }.freeze

    # Reads value of DHCLIENT_SET_HOSTNAME and translates it to boolean
    #
    # return {true, false, nil} "yes" => true, "no" => false, otherwise or not
    # present => nil
    def dhclient_set_hostname
      SYSCFG_TO_BOOL[SCR.Read(path(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"))]
    end

    # Reads value of WRITE_HOSTNAME_TO_HOSTS and translates it to boolean
    #
    # return {true, false, nil} "yes" => true, "no" => false, otherwise or not
    # present => nil
    def get_write_hostname_to_hosts
      SYSCFG_TO_BOOL[SCR.Read(path(".sysconfig.network.dhcp.WRITE_HOSTNAME_TO_HOSTS"))]
    end

    # Returns the YaST configuration
    #
    # @return [Y2Network::Config] LAN configuration
    def yast_dns_config
      Yast::Lan.Read(:cache)
      Yast::Lan.yast_config.dns
    end

    def system_dns_config
      Yast::Lan.Read(:cache)
      Yast::Lan.system_config.dns
    end

    publish variable: :domain, type: "string"
    publish function: :ReadNameserver, type: "boolean (string)"
    publish function: :DefaultWriteHostname, type: "boolean ()"
    publish function: :ReadHostname, type: "void ()"
    publish function: :ProposeHostname, type: "void ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Summary, type: "string ()"
    publish function: :IsHostLocal, type: "boolean (string)"
  end

  DNS = DNSClass.new
  DNS.main
end
