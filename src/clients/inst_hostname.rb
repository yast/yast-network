# encoding: utf-8

#***************************************************************************
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
#**************************************************************************
# File:	clients/inst_hostname.ycp
# Package:	Network configuration
# Summary:	Mandatory hostname configuration
# Authors:	Martin Vidner <mvidner@suse.cz>
#
module Yast
  class InstHostnameClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      Yast.import "Arch"
      Yast.import "DNS"
      Yast.import "GetInstArgs"
      Yast.import "Host"
      Yast.import "NetworkConfig"
      Yast.import "String"
      Yast.import "Wizard"
      Yast.import "ProductControl"
      Yast.import "ProductFeatures"

      Yast.include self, "network/services/dns.rb"


      # Called backwards
      #if(GetInstArgs::going_back())
      #   return `auto;

      # only once, do not re-propose if user gets back to this dialog from
      # the previous screen - bnc#438124
      if !DNS.proposal_valid
        DNS.Read # handles NetworkConfig too
        DNS.ProposeHostname # generate random hostname, if none known so far

        # propose settings
        DNS.dhcp_hostname = !Arch.is_laptop

        # get default value, from control.xml
        DNS.write_hostname = DNS.DefaultWriteHostname
      end

      @ret = :next

      #No need for interactive UI in automatic configuration
      if !GetInstArgs.automatic_configuration
        Wizard.SetDesktopIcon("dns")
        @ret = HostnameDialog()
      end

      if @ret == :next
        Host.Read
        Host.ResolveHostnameToStaticIPs
        Host.Write

        # do not let Lan override us, #152218
        DNS.proposal_valid = true 

        # delay writing, write along with the rest of network configuration
        # in lan_proposal
        # DNS::Write ();
      end

      @ret 

      # EOF
    end
  end
end

Yast::InstHostnameClient.new.main
