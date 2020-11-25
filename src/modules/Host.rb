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
require "y2network/autoinst_profile/host_section"
require "network/network_autoyast"

module Yast
  class HostClass < Module
    include Logger

    def main
      Yast.import "UI"
      textdomain "network"

      Yast.import "Hostname"
      Yast.import "NetworkInterfaces"
      Yast.import "String"
      Yast.import "Summary"

      Yast.include self, "network/routines.rb"

      @initialized = false

      @hosts = CFA::Hosts.new

      @configuration_imported = false
    end

    # Remove all entries from the host table.
    def clear
      @hosts.hosts.keys.each do |ip|
        @hosts.delete_by_ip(ip)
      end
      @configuration_imported = false
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
      log.info("Writing hosts configuration")

      # Check if there is anything to do
      if !GetModified()
        log.info("No changes to Host -> nothing to write")
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

      # Reset that the configuration has been taken from AY file because the settings
      # are now on the target system.
      @configuration_imported = false
      # Syncing after the settings have been written.
      @initial_hosts = @hosts.clone

      Progress.NextStage if gui

      true
    end

    # Get all the Hosts configuration from a map.
    # When called by hosts_auto (preparing autoinstallation data)
    # the map may be empty.
    #
    # @param [Hash] settings autoinstallation settings
    #               expected format of settings["hosts"] is { "ip" => [list, of, names] }
    # @return true if success
    def Import(settings)
      @initialized = true # don't let Read discard our data
      @configuration_imported = true if settings.key?("hosts")

      load_hosts(load_only: true)

      imported_hosts = settings.fetch("hosts", {})

      check_profile_for_errors(imported_hosts)

      # convert from old format to the new one
      # use ::1 entry as a reference
      if (imported_hosts["::1"] || []).size > 1
        imported_hosts.each_pair do |k, v|
          imported_hosts[k] = [v.join(" ")]
        end
      end

      imported_hosts.each_pair do |ip, names|
        set_names(ip, names)
      end

      true
    end

    # Dump the Hosts settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      exported_hosts = @hosts.hosts
      return {} if exported_hosts.empty?

      # Filter out IPs with empty hostname (so that valid autoyast
      # profile is created)(#335120)
      exported_hosts.keep_if { |_, names| !names.empty? }

      { "hosts" => exported_hosts }
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
    # @param oldhn [String, nil] hostname to be replaced
    # @param newhn [String] new hostname value
    # @param ip [String] to assign
    # @return [Boolean] true if success
    def Update(oldhn, newhn, ip)
      raise ArgumentError, "IP cannot be nil" if ip.nil?
      raise ArgumentError, "Nonempty IP expected" if ip.empty?

      log.info("Updating /etc/hosts: #{oldhn} -> #{newhn}: #{ip}")

      # Remove old hostname from hosts
      @hosts.delete_hostname(oldhn) if ![nil, ""].include?(oldhn)

      # Add localhost if missing
      @hosts.add_entry("127.0.0.1", "localhost") if @hosts.host("127.0.0.1").empty?

      # Omit some IP addresses
      return true if ["127.0.0.1", "", nil].include?(ip)
      # Omit invalid newhn
      return true if [nil, ""].include?(newhn)

      nick = Hostname.SplitFQ(newhn)[0] || ""
      nick = (nick.empty? || nick == newhn) ? [] : [nick]
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
      return Summary.NotConfigured if @hosts.hosts.empty?

      summary = Summary.OpenList("")
      @hosts.hosts.each do |k, v|
        next if GetSystemHosts().include?(k)

        # currently all names are placed as a one string in first array item
        summary = Summary.AddListItem(summary, "#{k} - #{v.first}")
      end

      Summary.CloseList(summary)
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
    # ips are configured to resolve to the system wide hostname (see Hostname module,
    # /etc/HOSTNAME)
    #
    # Originally implemented as a fix for bnc#664929, later extended for bnc#1039532
    def ResolveHostnameToStaticIPs
      Yast.import "DNS"

      # reject those static ips which have particular hostnames already configured
      static_ips = StaticIPs().reject { |sip| @hosts.include_ip?(sip) }
      return if static_ips.empty?

      fqhostname = DNS.hostname

      # assign system wide hostname to a static ip without particular hostname
      static_ips.each { |sip| Update(fqhostname, fqhostname, sip) }

      nil
    end

    # Function which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      return true if @configuration_imported # hosts section has been imported.

      @initial_hosts && (@hosts.hosts != @initial_hosts.hosts)
    end

    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :GetSystemHosts, type: "list ()"
    publish function: :Update, type: "boolean (string, string, list <string>)"
    publish function: :Summary, type: "string ()"
    publish function: :ResolveHostnameToStaticIPs, type: "void ()"
    publish function: :GetModified, type: "boolean ()"

  private

    # Give address a new list of names.
    def set_names(address, names)
      @hosts.delete_by_ip(address)
      names.each do |name|
        canonical, *aliases = name.split(" ")
        @hosts.add_entry(address, canonical, aliases)
      end
    end

    # Semantic AutoYaST profile check
    #
    # Problems will be stored in AutoInstall.issues_list.
    # @param imported_hosts [Hash] autoyast settings
    def check_profile_for_errors(imported_hosts)
      # Checking for empty hostnames
      imported_hosts.each do |ip, hosts|
        next unless hosts.any? { |host| host.strip.empty? }

        AutoInstall.issues_list.add(
          ::Installation::AutoinstIssues::InvalidValue,
          Y2Network::AutoinstProfile::HostSection.new_from_hashes(
            @param
          ),
          "names",
          "",
          # TRANSLATORS: %s is host address
          _("The name must not be empty for %s.") % ip
        )
      end
    end
  end

  # Initializes internal state according the /etc/hosts
  #
  # @param load_only [Boolean] true if you want load data and do not need to
  #                                 detect changes later (@see Host::GetModified)
  def load_hosts(load_only: false)
    return false if SCR.Read(path(".target.size"), CFA::Hosts::PATH) <= 0

    @hosts = CFA::Hosts.new
    @hosts.load

    # save hosts to check for changes later
    @initial_hosts = nil
    @initial_hosts = @hosts.clone if !load_only

    true

  # rescuing only those exceptions which are related to /etc/hosts access
  # (e.g. corrupted file, file access error, ...)
  rescue IOError, SystemCallError, RuntimeError => e
    log.error("Loading /etc/hosts failed with exception #{e.inspect}")

    # get clean environment, crashing due to exception is no option here
    @hosts = CFA::Hosts.new
    @initial_hosts = nil

    # reraise the exception - let the gui takes care of it
    raise
  end

  Host = HostClass.new
  Host.main
end
