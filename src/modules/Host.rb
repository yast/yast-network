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
#
require "yast"
require "yast2/execute"
require "cfa/hosts"

module Yast
  class HostClass < Module
    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "DNS"
      Yast.import "Hostname"
      Yast.import "NetworkInterfaces"
      Yast.import "String"
      Yast.import "Summary"
      Yast.import "AutoInstall"

      Yast.include self, "network/routines.rb"

      # Data was modified?
      # TODO: Drop the flag. It is useless since we have @hosts and @hosts_init
      @modified = false

      @initialized = false

      @hosts = CFA::Hosts.new
    end

    # Remove all entries from the host table.
    def clear(keep_defaults: false)
      @hosts.hosts.keys.each do |ip|
        next if keep_defaults && GetSystemHosts().include?(ip)
        @hosts.delete_by_ip(ip)
      end
      @modified = true
    end

    # @return [hash] address->list of names
    def name_map
      @hosts.hosts
    end

    # @return [array] names for that address
    def names(address)
      @hosts.host(address) || []
    end

    # remove all instances of ip in hosts table
    def remove_ip(address)
      @hosts.delete_by_ip(address)
    end

    # Add another name to the list for address (which may be empty so far)
    # FIXME: used only in one place, which looks wrong
    def add_name(address, name)
      canonical, *aliases = name.split(" ")
      @hosts.add_entry(address, canonical, aliases)

      @modified = true
    end

    def NeedDummyIP
      DNS.write_hostname
    end

    def EnsureHostnameResolvable
      local_ip = "127.0.0.2"
      if NeedDummyIP()
        Builtins.y2milestone("Dummy 127.0.0.2 IP will be added")
        # Add 127.0.0.2 entry to /etc/hosts,if product default says so
        # or user requests it otherwise some desktop apps may hang,
        # being unable to resolve hostname (bnc#304632)

        fqhostname = Hostname.MergeFQ(DNS.hostname, DNS.domain)
        set_names(local_ip, ["#{fqhostname} #{DNS.hostname}"])
        @modified = true
      elsif @hosts.include_ip?(local_ip)
        # Do not add it if product default says no
        # and remove 127.0.02 entry if it exists

        @hosts.delete_by_ip(local_ip)
        @modified = true
      end

      nil
    end

    # Reads /etc/hosts settings
    #
    # It reads /etc/hosts only when the module was not initialized already.
    #
    # @return true if success, raises an exception in case of malformed file
    def Read
      return true if @initialized
      return false if !load_hosts

      Builtins.y2debug("hosts=#{@hosts.inspect}")

      @initialized = true
    end

    # Write hosts settings and apply changes
    # @return true if success
    def Write(gui: false)
      Builtins.y2milestone("Writing hosts configuration")

      if !@modified
        Builtins.y2milestone("No changes to Host -> nothing to write")
        return true
      end

      # Check if there is anything to do
      if @hosts_init == @hosts
        Builtins.y2milestone("Hosts not modified")
        return true
      end

      if gui
        steps = [_("Update /etc/hosts")]

        caption = _("Saving Hostname Configuration")

        Progress.New(caption, " ", steps.size, steps, [], "")

        ProgressNextStage(_("Updating /etc/hosts ..."))
      end

      # backup if exists
      if SCR.Read(path(".target.size"), CFA::Hosts::PATH) >= 0
        Yast::Execute.on_target("cp", CFA::Hosts::PATH, "#{CFA::Hosts::PATH}.YaST2save")
      end

      @hosts.save

      Progress.NextStage if gui

      true
    end

    # Imports the Hosts configuration of defined in the profile section merging
    # the configuration with the defaults.
    #
    # It permits duplicate entries although will blame about it
    #
    # @example importing some duplicate entries
    #   Yast::Host.Import( "hosts" => [
    #     {
    #       "host_address" => "192.168.122.1",
    #       "names" => ["server.example.com", "server"]
    #     },
    #     {
    #       "host_address" => "192.168.122.1",
    #       "Permit entries defined in just one string item or in various"
    #       "names" => ["ftp.example.com ftp"]
    #     }
    #   ])
    #
    #   # Etc content
    #   ... defaults should be here
    #   192.168.122.1 server.example.com server
    #   192.168.122.1 ftp.example.com ftp
    #
    # @param settings [Hash] autoinstallation settings
    # @return true if success
    def Import(settings)
      Read()
      clear(keep_defaults: true)
      host_entries = settings.fetch("hosts", [])
      return true if host_entries.empty?
      imported_hosts = {}
      host_entries.each do |host|
        ip = host["host_address"]
        names = parse_host_names(host.fetch("names", []))
        if names.empty?
          add_issue(ip, :empty_name)
          next
        end
        # Multiple entries are permited
        imported_hosts[ip] ||= []
        imported_hosts[ip] << names
      end

      imported_hosts.each_pair do |ip, names|
        add_issue(ip, :duplicates) if names.size > 1
        set_names(ip, names)
      end

      @modified = true
    end

    # Dump the Hosts settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      exported_hosts = @hosts.hosts
      return {} if exported_hosts.empty?
      host_entries = []

      exported_hosts.each do |host, names|
        names.each { |n| host_entries << { "host_address" => host, "names" => n.split } }
      end

      { "hosts" => host_entries }
    end

    # Return "system" predefined hosts (should be present all the time)
    # @return [Array] of system hosts
    def GetSystemHosts
      [
        "127.0.0.1",
        "::1",
        "fe00::0",
        "ff00::0",
        "ff02::1",
        "ff02::2",
        "ff02::3"
      ]
    end

    # Update hosts according to the current hostname
    # (only one hostname, assigned to all IP)
    # @param oldhn [String] current hostname
    # @param newhn [String] current domain name
    # @param ip [String] to assign
    # @return [Boolean] true if success
    def Update(oldhn, newhn, ip)
      raise ArgumentError, "IP cannot be nil" if ip.nil?
      raise ArgumentError, "Nonempty IP expected" if ip.empty?

      log.info("Updating /etc/hosts: #{oldhn} -> #{newhn}: #{ip}")

      @modified = true

      # Remove old hostname from hosts
      @hosts.delete_hostname(oldhn) if !oldhn.empty?

      # Add localhost if missing
      if @hosts.host("127.0.0.1").empty?
        @hosts.add_entry("127.0.0.1", "localhost")
      end

      # Omit some IP addresses
      return true if ["127.0.0.1", "", nil].include?(ip)
      # Omit invalid newhn
      return true if [nil, ""].include?(newhn)

      nick = Hostname.SplitFQ(newhn)[0] || ""
      nick = nick.empty? || nick == newhn ? [] : [nick]
      hosts = @hosts.host(ip)
      if hosts.empty?
        @hosts.add_entry(ip, newhn, nick)
      else
        canonical, *aliases = hosts.last.split(" ")
        aliases << newhn
        aliases.concat(nick)
        @hosts.set_entry(ip, canonical, aliases)
      end

      true
    end

    # Create summary
    # @return summary text
    def Summary
      summary = ""
      return Summary.NotConfigured if @hosts.hosts.empty?

      summary = Summary.OpenList(summary)
      @hosts.hosts.each do |k, v|
        Builtins.foreach(v) do |hn|
          summary = Summary.AddListItem(summary, Ops.add(Ops.add(k, " - "), hn))
        end if !Builtins.contains(
          GetSystemHosts(),
          k
        )
      end
      summary = Summary.CloseList(summary)
      summary
    end

    # Creates a list os static ips present in the system
    #
    # @return [Array<string>] list of ip addresses
    def StaticIPs
      NetworkInterfaces.Read
      devs = NetworkInterfaces.Locate("BOOTPROTO", "static")

      devs.reject! { |dev| dev == "lo" }
      static_ips = devs.map { |dev| NetworkInterfaces.GetValue(dev, "IPADDR") }
      static_ips.reject! { |ip| ip.nil? || ip.empty? }

      log.info("StaticIPs: found in ifcfgs: #{devs} IPs list: #{static_ips}")

      static_ips
    end

    # Configure system to resolve static ips without hostname to system wide hostname
    #
    # It is expected to be used during installation only. If user configures static
    # ips during installation and do not assign them particular hostname, then such
    # ips are configuret to resolve to the system wide hostname (see Hostname module,
    # /etc/HOSTNAME)
    #
    # Originally implemented as a fix for bnc#664929, later extended for bnc#1039532
    def ResolveHostnameToStaticIPs
      # reject those static ips which have particular hostnames already configured
      static_ips = StaticIPs().reject { |sip| @hosts.include_ip?(sip) }
      return if static_ips.empty?

      fqhostname = Hostname.MergeFQ(DNS.hostname, DNS.domain)

      # assign system wide hostname to a static ip without particular hostname
      static_ips.each { |sip| Update(fqhostname, fqhostname, sip) }

      nil
    end

    # Function which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    publish function: :NeedDummyIP, type: "boolean ()"
    publish function: :EnsureHostnameResolvable, type: "void ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :GetSystemHosts, type: "list ()"
    publish function: :Update, type: "boolean (string, string, list <string>)"
    publish function: :Summary, type: "string ()"
    publish function: :ResolveHostnameToStaticIPs, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish function: :SetModified, type: "void ()"

  private

    # Append to the list of AutoYaST issues for being reported the given one
    #
    # @param ip [String] host address wiith some issue
    # @param issue [Symbol] the specific problem to be reported
    def add_issue(ip, issue)
      case issue
      when :empty_name
        AutoInstall.issues_list.add(:invalid_value, "host", "names",
          "",
          # TRANSLATORS: %s is host address
          _("The name must not be empty for %s.") % ip)
      when :duplicates
        AutoInstall.issues_list.add(:invalid_value, "host", "host_address",
          "",
          # TRANSLATORS: %s is host address
          _("The IP address %s is defined multiple times which is not recommended.") % ip)
      end
    end

    # Give address a new list of names.
    def set_names(address, names)
      @hosts.delete_by_ip(address)
      names.each do |name|
        canonical, *aliases = name.split(" ")
        @hosts.add_entry(address, canonical, aliases)
      end
      @modified = true
    end

    # Given a list of names it return a string with all of them separated by a
    # space. It permits multiple names in the same entry as previously
    #
    # @example parsing multiple names with extra spaces
    #   parse_host_names(["example.suse.de  example ", " test "])
    #   => "example.suse.de example test"
    #
    # @param names [Array<String>] list of name entries
    # @return [String]
    def parse_host_names(names)
      names.map { |n| n.split(" ") }.flatten.uniq.join(" ")
    end
  end

  # Initializes internal state according the /etc/hosts
  def load_hosts
    return false if SCR.Read(path(".target.size"), CFA::Hosts::PATH) <= 0

    @hosts = CFA::Hosts.new
    @hosts.load

    # save hosts to check for changes later
    @hosts_init = CFA::Hosts.new
    @hosts_init.load

    true

  # rescuing only those exceptions which are related to /etc/hosts access
  # (e.g. corrupted file, file access error, ...)
  rescue IOError, SystemCallError, RuntimeError => error
    log.error("Loading /etc/hosts failed with exception #{error.inspect}")

    # get clean environment, crashing due to exception is no option here
    @hosts = CFA::Hosts.new
    @hosts_init = nil

    # reraise the exception - let the gui takes care of it
    raise
  end

  Host = HostClass.new
  Host.main
end
