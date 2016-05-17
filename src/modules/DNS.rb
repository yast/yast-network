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

module Yast
  class DNSClass < Module
    include Logger

    HOSTNAME_FILE = "hostname"
    HOSTNAME_PATH = "/etc/" + HOSTNAME_FILE

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Arch"
      Yast.import "NetHwDetection"
      Yast.import "Hostname"
      Yast.import "IP"
      Yast.import "NetworkInterfaces"
      Yast.import "ProductFeatures"
      Yast.import "Progress"
      Yast.import "Service"
      Yast.import "String"
      Yast.import "FileUtils"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/runtime.rb"

      # Should the hostname be proposed? #152218
      @proposal_valid = false

      # Short Hostname
      @hostname = ""

      # Domain Name (not including the host part)
      @domain = ""

      @nameservers = []
      @searchlist = []

      @dhcp_hostname = false
      @write_hostname = false
      @resolv_conf_policy = ""

      # fully qualified
      @oldhostname = ""

      # Data was modified?
      @modified = false

      # resolver config file location
      @resolv_conf = "/etc/resolv.conf"

      # True if DNS is already read
      @initialized = false
    end

    # Use the parameter, coming usually from install.inf, if it is defined.
    # Used when there is nothing better.
    # @param [String] ns ip of the nameserver
    # @return true if success
    def ReadNameserver(ns)
      return false if ns == "" || ns.nil?
      @nameservers = [ns]
      # modified = true;
      true
    end

    # Use this host and domain name, if they are defined
    # @param [String] hn hostname
    # @param [String] dn domain name
    # @return true if the hostname has been assigned
    def ReadHostDomain(hn, dn)
      return false if hn == "" || hn.nil? || dn.nil?
      @hostname = hn
      @domain = dn
      # modified = true;
      true
    end

    # Get current hostname and IP Address
    # if these are set by DHCP
    # @return map with ip, hostname_short and hostname_fq keys
    def GetDHCPHostnameIP
      ret = {}

      output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "hostname -i")
      )
      Ops.set(
        ret,
        "ip",
        Builtins.deletechars(Ops.get_string(output, "stdout", ""), " \n")
      )

      output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "hostname")
      )
      Ops.set(
        ret,
        "hostname_short",
        Builtins.deletechars(Ops.get_string(output, "stdout", ""), " \n")
      )

      output = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), "hostname -f")
      )
      Ops.set(
        ret,
        "hostname_fq",
        Builtins.deletechars(Ops.get_string(output, "stdout", ""), " \n")
      )

      deep_copy(ret)
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
      command = "/usr/bin/getent hosts \"%1\""
      getent = Convert.to_map(
        SCR.Execute(path(".target.bash_output"), Builtins.sformat(command, ip))
      )
      exit_code = Ops.get_integer(getent, "exit", -1)

      if exit_code != 0
        Builtins.y2error("ResolveIP: getent call failed (%1)", exit_code)

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

    def ReadHostname
      # In installation (standard, or AutoYaST one), prefer /etc/install.inf
      # (because HOSTNAME comes with netcfg.rpm already, #144687)
      if (Mode.installation || Mode.autoinst) && FileUtils.Exists("/etc/install.inf")
        fqhostname = read_hostname_from_install_inf
      end

      # reads setup from /etc/HOSTNAME, returns a default if nothing found
      fqhostname = Hostname.CurrentFQ if fqhostname.nil? || fqhostname.empty?

      @hostname, @domain = *Hostname.SplitFQ(fqhostname)

      nil
    end

    def ProposeHostname
      if @hostname == "linux"
        Builtins.srandom
        @hostname = Ops.add("linux-", String.Random(4)) # #157107
        @modified = true
      end

      nil
    end

    # Reads current DNS and hostname settings
    # Includes Host,NetworkConfig::Read
    # @return true if success
    def Read
      return true if @initialized == true

      tmp1 = Convert.to_string(
        SCR.Read(path(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"))
      )
      @dhcp_hostname = tmp1 == "yes"
      tmp2 = Convert.to_string(
        SCR.Read(path(".sysconfig.network.dhcp.WRITE_HOSTNAME_TO_HOSTS"))
      )
      @write_hostname = tmp2 == "yes"

      @resolv_conf_policy = Convert.to_string(
        SCR.Read(path(".sysconfig.network.config.NETCONFIG_DNS_POLICY"))
      )
      resolvlist = Builtins.splitstring(
        Convert.to_string(
          SCR.Read(
            path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS")
          )
        ),
        " "
      )
      if Ops.greater_than(Builtins.size(resolvlist), 0)
        @nameservers = deep_copy(resolvlist)
      end

      @searchlist = Builtins.splitstring(
        Convert.to_string(
          SCR.Read(
            path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST")
          )
        ),
        " "
      )

      # hostname and domain
      ReadHostname()
      @oldhostname = Hostname.MergeFQ(@hostname, @domain)

      Builtins.y2milestone("nameservers=%1", @nameservers)
      Builtins.y2milestone("searchlist=%1", @searchlist)
      Builtins.y2milestone("hostname=%1", @hostname)
      Builtins.y2milestone("domain=%1", @domain)

      @initialized = true
      true
    end

    # Write new DNS and hostname settings
    # Includes Host,NetworkConfig::Write
    # @return true if success
    def Write
      # build FQ hostname
      fqhostname = Hostname.MergeFQ(@hostname, @domain)

      # We do not collect static IP addresses here, as hostnames
      # are defined for each static IP separately in address dialog
      # FaTE #2202

      @oldhostname = fqhostname # #49634

      # ensure that nothing is saved in case old values are the same, as it makes
      # rcnetwork reload restart all interfaces (even 'touch /etc/sysconfig/network/dhcp'
      # is sufficient)
      tmp = SCR.Read(path(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"))
      old_dhcp_hostname = tmp == "yes"

      tmp = SCR.Read(path(".sysconfig.network.dhcp.WRITE_HOSTNAME_TO_HOSTS"))
      old_write_hostname = tmp == "yes"

      if old_dhcp_hostname != dhcp_hostname || old_write_hostname != write_hostname
        SCR.Write(
          path(".sysconfig.network.dhcp.DHCLIENT_SET_HOSTNAME"),
          @dhcp_hostname ? "yes" : "no"
        )
        SCR.Write(
          path(".sysconfig.network.dhcp.WRITE_HOSTNAME_TO_HOSTS"),
          @write_hostname ? "yes" : "no"
        )
        SCR.Write(path(".sysconfig.network.dhcp"), nil)
      end

      Builtins.y2milestone("Writing configuration")
      if !@modified
        Builtins.y2milestone("No changes to DNS -> nothing to write")
        return true
      end

      Builtins.y2milestone("nameservers=%1", @nameservers)
      Builtins.y2milestone("searchlist=%1", @searchlist)
      Builtins.y2milestone("hostname=%1", @hostname)
      Builtins.y2milestone("domain=%1", @domain)
      Builtins.y2milestone(
        "dhcp_hostname=%1, write_hostname=%2",
        @dhcp_hostname,
        @write_hostname
      )

      steps = [
        # Progress stage 1
        _("Write hostname"),
        # Progress stage 2
        _("Update configuration"),
        # Progress stage 3
        _("Update /etc/resolv.conf")
      ]

      # Write dialog caption
      caption = _("Saving Hostname and DNS Configuration")
      sl = 0 # 100; for testing

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      # Allow to set hostname even if it's modified by DHCP (#13427)
      # if(NetworkConfig::DHCP["DHCLIENT_SET_HOSTNAME"]:false != true) {

      # Progress step 1/3
      ProgressNextStage(_("Writing hostname..."))

      # change the hostname
      SCR.Execute(path(".target.bash"), Ops.add("/bin/hostname ", @hostname))

      # write hostname
      SCR.Write(
        path(".target.string"),
        HOSTNAME_PATH,
        Ops.add(fqhostname, "\n")
      )

      create_hostname_link

      Builtins.sleep(sl)

      # Progress step 2/3
      ProgressNextStage(_("Updating configuration..."))

      # Finish him
      update_mta_config
      Builtins.sleep(sl)

      #     if(SCR::Read(.target.size, resolv_conf) < 0)
      # SCR::Write(.target.string, resolv_conf, "");

      # Progress step 3/3
      ProgressNextStage(_("Updating /etc/resolv.conf ..."))

      SCR.Write(
        path(".sysconfig.network.config.NETCONFIG_DNS_POLICY"),
        @resolv_conf_policy
      )
      SCR.Write(
        path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SEARCHLIST"),
        Builtins.mergestring(@searchlist, " ")
      )
      SCR.Write(
        path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS"),
        Builtins.mergestring(@nameservers, " ")
      )
      SCR.Write(path(".sysconfig.network.config"), nil)

      SCR.Execute(path(".target.bash"), "/sbin/netconfig update")

      Builtins.sleep(sl)

      Progress.NextStage
      @modified = false
      true
    end

    # Get all the DNS configuration from a map.
    # When called by dns_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings autoinstallation settings
    # @return true if success
    def Import(settings)
      settings = deep_copy(settings)
      @dhcp_hostname = settings.fetch("dhcp_hostname") { default_dhcp_hostname }
      # if not defined, set to 'auto'
      @resolv_conf_policy = Ops.get_string(
        settings,
        "resolv_conf_policy",
        "auto"
      )

      # user-defined value has higher priority - FaTE#305281
      if Builtins.haskey(settings, "write_hostname")
        @write_hostname = Ops.get_boolean(settings, "write_hostname", false)
      else
        # otherwise, use control.xml default
        @write_hostname = DefaultWriteHostname()
      end

      # user-defined <hostname>
      if Builtins.haskey(settings, "hostname")
        @hostname = Ops.get_string(settings, "hostname", "")
        @domain = Ops.get_string(settings, "domain", "") # empty is not a bug, bnc#677471
      else
        # otherwise, check 1) install.inf 2) /etc/HOSTNAME
        ReadHostname()
        # if nothing is found, generate a random one
        ProposeHostname()
      end

      @nameservers = Builtins.eval(Ops.get_list(settings, "nameservers", []))
      @searchlist = Builtins.eval(Ops.get_list(settings, "searchlist", []))
      @modified = true
      # empty settings means that we're probably resetting the config
      # thus, setup is not initialized anymore
      @initialized = settings != {}

      Builtins.y2milestone("DNS Import:")
      Builtins.y2milestone("nameservers=%1", @nameservers)
      Builtins.y2milestone("searchlist=%1", @searchlist)
      Builtins.y2milestone("hostname=%1", @hostname)
      Builtins.y2milestone("domain=%1", @domain)
      Builtins.y2milestone(
        "dhcp_hostname=%1, write_hostname=%2",
        @dhcp_hostname,
        @write_hostname
      )

      true
    end

    # Dump the DNS settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      expdns = {}

      # It should be case only for installer (1st stage). When resolver / hostname
      # was configured via linuxrc, yast needn't to be aware of it. bnc#957377
      Read() if !@initialized

      if Ops.greater_than(Builtins.size(@hostname), 0)
        Ops.set(expdns, "hostname", @hostname)
      end
      if Ops.greater_than(Builtins.size(@domain), 0)
        Ops.set(expdns, "domain", @domain)
      end
      if Ops.greater_than(Builtins.size(@nameservers), 0)
        Ops.set(expdns, "nameservers", Builtins.eval(@nameservers))
      end
      if Ops.greater_than(Builtins.size(@searchlist), 0)
        Ops.set(expdns, "searchlist", Builtins.eval(@searchlist))
      end
      Ops.set(expdns, "dhcp_hostname", @dhcp_hostname)
      # TODO: test if it really works with empty string
      Ops.set(expdns, "resolv_conf_policy", @resolv_conf_policy)
      # bnc#576495, FaTE#305281 - clone write_hostname, too
      Ops.set(expdns, "write_hostname", @write_hostname)
      deep_copy(expdns)
    end

    # Create DNS text summary
    # @return summary text
    def Summary
      Yast.import "Summary"
      summary = ""

      has_dhcp = Ops.greater_than(
        Builtins.size(NetworkInterfaces.Locate("BOOTPROTO", "dhcp")),
        0
      )

      if has_dhcp && @dhcp_hostname
        # Summary text
        summary = Summary.AddListItem(summary, _("Hostname: Set by DHCP"))
      elsif Ops.greater_than(Builtins.size(@hostname), 0)
        # Summary text
        summary = Summary.AddListItem(
          summary,
          Builtins.sformat(
            _("Hostname: %1"),
            Hostname.MergeFQ(@hostname, @domain)
          )
        )
      end
      if !@write_hostname
        summary = Summary.AddListItem(
          summary,
          _("Hostname will not be written to /etc/hosts")
        )
      end

      # if (has_dhcp && NetworkConfig::DHCP["DHCLIENT_MODIFY_RESOLV_CONF"]:false) {
      # Summary text
      # summary = Summary::AddListItem(summary, _("Name Servers: Set by DHCP"));
      # Summary text
      # summary = Summary::AddListItem(summary, _("Search List: Set by DHCP"));
      # }
      # else {
      nslist = Builtins.maplist(@nameservers) do |ns|
        nss = NetHwDetection.ResolveIP(ns)
        nss == "" ? ns : Ops.add(Ops.add(Ops.add(ns, " ("), nss), ")")
      end

      if Ops.greater_than(Builtins.size(nslist), 0)
        # Summary text
        summary = Summary.AddListItem(
          summary,
          Builtins.sformat(
            _("Name Servers: %1"),
            Builtins.mergestring(nslist, ", ")
          )
        )
      end
      if Ops.greater_than(Builtins.size(@searchlist), 0)
        # Summary text
        summary = Summary.AddListItem(
          summary,
          Builtins.sformat(
            _("Search List: %1"),
            Builtins.mergestring(@searchlist, ", ")
          )
        )
      end
      # }

      return "" if Ops.less_than(Builtins.size(summary), 1)
      Ops.add(Ops.add("<ul>", summary), "</ul>")
    end

    # Check if hostname or IP address is local computer
    # Used to determine if LDAP server is local (and it should be checked if
    #  required schemes are included
    # Calls Read () function before querying any data
    # @param [String] check_host string hostname or IP address to check
    # @return [Boolean] true if hostname is local host
    def IsHostLocal(check_host)
      Read()
      NetworkInterfaces.Read
      dhcp_data = {}

      if Ops.greater_than(
        Builtins.size(NetworkInterfaces.Locate("BOOTPROTO", "dhcp")),
        0
        ) || @dhcp_hostname
        dhcp_data = GetDHCPHostnameIP()
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
      else
        if Builtins.tolower(check_host) ==
            Builtins.tolower(Ops.add(Ops.add(@hostname, "."), @domain)) ||
            Ops.get(dhcp_data, "hostname_fq", "") == check_host
          return true
        end
      end
      false
    end

    # Creates symlink /etc/HOSTNAME -> /etc/hostname to gurantee backward compatibility
    # after changes in bnc#858908
    def create_hostname_link
      link_name = "/etc/HOSTNAME"
      return if FileUtils.IsLink(link_name)

      log.info "Creating #{link_name} symlink"

      SCR.Execute(path(".target.bash"), "rm #{link_name}") if FileUtils.Exists(link_name)
      SCR.Execute(path(".target.bash"), "ln -s #{DNSClass::HOSTNAME_PATH} #{link_name}")

      nil
    end

  private

    def read_hostname_from_install_inf
      install_inf_hostname = SCR.Read(path(".etc.install_inf.Hostname")) || ""
      log.info("Got #{install_inf_hostname} from install.inf")

      return "" if install_inf_hostname.empty?

      # if the name is actually IP, try to resolve it (bnc#556613, bnc#435649)
      if IP.Check(install_inf_hostname)
        fqhostname = ResolveIP(install_inf_hostname)
        log.info("Got #{fqhostname} after resolving IP from install.inf")
      else
        fqhostname = install_inf_hostname
      end

      # We have non-empty hostname by now => we must set DNS modified flag
      # in order to get the setting actually written (bnc#588938)
      @modified = true if !fqhostname.empty?

      fqhostname
    end

    publish variable: :proposal_valid, type: "boolean"
    publish variable: :hostname, type: "string"
    publish variable: :domain, type: "string"
    publish variable: :nameservers, type: "list <string>"
    publish variable: :searchlist, type: "list <string>"
    publish variable: :dhcp_hostname, type: "boolean"
    publish variable: :write_hostname, type: "boolean"
    publish variable: :resolv_conf_policy, type: "string"
    publish variable: :modified, type: "boolean"
    publish function: :ReadNameserver, type: "boolean (string)"
    publish function: :ReadHostDomain, type: "boolean (string, string)"
    publish function: :GetDHCPHostnameIP, type: "map <string, string> ()"
    publish function: :DefaultWriteHostname, type: "boolean ()"
    publish function: :ReadHostname, type: "void ()"
    publish function: :ProposeHostname, type: "void ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :Summary, type: "string ()"
    publish function: :IsHostLocal, type: "boolean (string)"
  end

  DNS = DNSClass.new
  DNS.main
end
