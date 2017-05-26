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
# File:	modules/Host.ycp
# Package:	Network configuration
# Summary:	Hosts data (/etc/hosts)
# Authors:	Michal Svec <msvec@suse.cz>
#
require "yast"

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

      Yast.include self, "network/routines.rb"

      # All hosts
      # See hosts(5)
      # keys: IPs, (But #35671 suggests that repeating IPs is valid)
      # values: names, the first one is the canonical one
      @hosts = {}

      # Data was modified?
      @modified = false

      # All hosts read at the start
      @hosts_init = {}

      # "hosts" file location
      @hosts_file = "/etc/hosts"

      @initialized = false
    end

    # Remove all entries from the host table.
    def clear
      @hosts = {}
      @modified = true
    end

    # @return [hash] address->list of names
    def name_map
      @hosts
    end

    # @return [array] names for that address
    def names(address)
      @hosts[address] || []
    end

    # Give address a new list of names.
    def set_names(address, names)
      @hosts[address] = names
      @modified = true
    end

    # Add another name to the list for address (which may be empty so far)
    def add_name(address, name)
      @hosts[address] ||= []
      @hosts[address] << name

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
        Ops.set(
          @hosts,
          local_ip,
          [Ops.add(Ops.add(fqhostname, " "), DNS.hostname)]
        )
      elsif Builtins.haskey(@hosts, local_ip)
        # Do not add it if product default says no
        # and remove 127.0.02 entry if it exists
        Ops.set(@hosts, local_ip, [])
      end
      @modified = true

      nil
    end

    # Read hosts settings
    # @return true if success
    def Read
      return true if @initialized == true

      # read /etc/hosts
      if Ops.greater_than(SCR.Read(path(".target.size"), @hosts_file), 0)
        hostlist = SCR.Dir(path(".etc.hosts"))
        @hosts = Builtins.listmap(hostlist) do |host|
          names = Convert.convert(
            SCR.Read(
              Builtins.topath(Builtins.sformat(".etc.hosts.\"%1\"", host))
            ),
            from: "any",
            to:   "list <string>"
          )
          next { host => names } if names != []
        end
      end

      # save hosts to check for changes later
      @hosts_init = deep_copy(@hosts)

      Builtins.y2debug("hosts=%1", @hosts)
      @initialized = true
      true
    end

    # Write hosts settings and apply changes
    # @return true if success
    def Write
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

      steps = [_("Update /etc/hosts")]

      caption = _("Saving Hostname Configuration")
      sl = 500 # sleep for longer time, so that progress does not disappear right afterwards

      Progress.New(caption, " ", Builtins.size(steps), steps, [], "")

      ProgressNextStage(_("Updating /etc/hosts ..."))

      # Create if not exists, otherwise backup
      if Ops.less_than(SCR.Read(path(".target.size"), @hosts_file), 0)
        SCR.Write(path(".target.string"), @hosts_file, "")
      else
        SCR.Execute(
          path(".target.bash"),
          Ops.add(
            Ops.add(Ops.add(Ops.add("/bin/cp ", @hosts_file), " "), @hosts_file),
            ".YaST2save"
          )
        )
      end

      ret = false
      if @hosts == {} || @hosts.nil?
        # Workaround bug [#4476]
        ret = SCR.Write(path(".target.string"), @hosts_file, "")
      else
        # Update the hosts config
        Builtins.y2milestone("hosts=%1", @hosts)
        Builtins.maplist(@hosts) do |ho, names|
          Builtins.y2milestone(
            "%1 (%2:%3)",
            ho,
            names,
            Ops.get(@hosts_init, ho)
          )
          SCR.Write(Builtins.add(path(".etc.hosts"), ho), names)
        end
        ret = true
      end

      SCR.Write(path(".etc.hosts"), nil)
      Builtins.sleep(sl)
      Progress.NextStage
      ret == true
    end

    # Get all the Hosts configuration from a map.
    # When called by hosts_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings autoinstallation settings
    # @return true if success
    def Import(settings)
      settings = deep_copy(settings)
      @modified = true # trigger Write
      @initialized = true # don't let Read discard our data

      @hosts = Builtins.eval(Ops.get_map(settings, "hosts", {}))

      # convert from old format to the new one
      # use ::1 entry as a reference
      if Ops.greater_than(Builtins.size(Ops.get(@hosts, "::1", [])), 1)
        Builtins.foreach(@hosts) do |ip, hn|
          Ops.set(@hosts, ip, [Builtins.mergestring(hn, " ")])
        end
      end
      true
    end

    # Dump the Hosts settings to a map, for autoinstallation use.
    # @return autoinstallation settings
    def Export
      return {} if @hosts.empty?

      # Filter out IPs with empty hostname (so that valid autoyast
      # profile is created)(#335120)
      # FIXME: this also removes records with empty names from @hosts. Such
      # side effect is unexpected and should be removed.
      @hosts.keep_if { |_, names| !names.empty? }

      { "hosts" => @hosts }
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
    # (only one hostname, assigned to all IPs)
    # @param hostname current hostname
    # @param domain current domain name
    # @param [Array<String>] iplist localhost IP addresses
    # @return true if success
    def Update(oldhn, newhn, iplist)
      iplist = deep_copy(iplist)
      ips = Builtins.filter(iplist) { |ip| ip != "127.0.0.1" }

      Builtins.y2milestone("Hosts: %1", @hosts)
      Builtins.y2milestone(
        "Updating /etc/hosts: %1 -> %2: %3",
        oldhn,
        newhn,
        ips
      )
      @modified = true

      nick = Ops.get(Hostname.SplitFQ(newhn), 0, "")

      # Remove old hostname from hosts
      if !oldhn.empty?
        Builtins.foreach(@hosts) do |ip, hs|
          wrk = Builtins.maplist(hs) { |s| Builtins.splitstring(s, " ") }
          wrk = Builtins.filter(wrk) { |lst| !Builtins.contains(lst, oldhn) }
          Ops.set(@hosts, ip, Builtins.maplist(wrk) do |lst|
            Builtins.mergestring(lst, " ")
          end)
        end
      end

      # Resurect the rest of oldhnlist without old hostname
      # FIXME: maybe

      # Add localhost if missing
      if !Builtins.haskey(@hosts, "127.0.0.1")
        Ops.set(@hosts, "127.0.0.1", ["localhost"])
      end

      # Add hostname/ip for all ips
      nickadded = false
      Builtins.maplist(ips) do |ip|
        # Omit some IP addresses
        next if ip == "" || ip.nil? || ip == "127.0.0.1"
        name = newhn
        # Add nick for the first one
        if !nickadded && name != ""
          nickadded = true
          name = Ops.add(Ops.add(newhn, " "), nick)
        end
        Ops.set(@hosts, ip, Builtins.add(Ops.get(@hosts, ip, []), name))
      end

      Builtins.y2milestone("Hosts: %1", @hosts)

      true
    end

    # Create summary
    # @return summary text
    def Summary
      summary = ""
      return Summary.NotConfigured if @hosts == {}

      summary = Summary.OpenList(summary)
      Builtins.foreach(@hosts) do |k, v|
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

    def StaticIPs
      NetworkInterfaces.Read
      devs = NetworkInterfaces.Locate("BOOTPROTO", "static")
      devs = Builtins.filter(devs) { |dev| dev != "lo" }
      ips = Builtins.maplist(devs) do |dev|
        NetworkInterfaces.GetValue(dev, "IPADDR")
      end
      Builtins.y2milestone("ifcfgs: %1 IPs: %2", devs, ips)
      deep_copy(ips)
    end

    # if we have a static address,
    # make sure /etc/hosts resolves it to our, bnc#664929
    def ResolveHostnameToStaticIPs
      # reject those static ips which have particular hostnames already configured
      static_ips = StaticIPs().reject { |sip| !names(sip).empty? }
      return if static_ips.empty?

      fqhostname = Hostname.MergeFQ(DNS.hostname, DNS.domain)
      Update(fqhostname, fqhostname, static_ips)

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
  end

  Host = HostClass.new
  Host.main
end
