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
# File:	clients/dns.ycp
# Package:	Network configuration
# Summary:	Hostname and DNS client
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for hostname and DNS configuration.
# Uses all other files.
module Yast
  class DnsClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("DNS module started")

      Yast.import "DNS"
      Yast.import "Label"
      Yast.import "Lan"
      Yast.import "NetworkService"
      Yast.import "Wizard"

      Yast.import "CommandLine"
      Yast.import "RichText"

      Yast.include self, "network/runtime.rb"
      Yast.include self, "network/services/dns.rb"

      @HOSTNAME = "hostname"
      @NAMESERVER_1 = "nameserver1"
      @NAMESERVER_2 = "nameserver2"
      @NAMESERVER_3 = "nameserver3"

      # Command line definition
      @cmdline = {
        # Commandline help title
        "help"       => _("DNS Configuration"),
        "id"         => "dns",
        "guihandler" => fun_ref(method(:DNSGUI), "any ()"),
        "initialize" => fun_ref(method(:InitHandler), "boolean ()"),
        "finish"     => fun_ref(method(:FinishHandler), "boolean ()"),
        "actions"    => {
          "list" => {
            # Commandline command help
            "help"    => _(
              "Display configuration summary"
            ),
            "handler" => fun_ref(
              method(:ListHandler),
              "boolean (map <string, string>)"
            )
          },
          "edit" => {
            "help"    => _("Edit current settings"),
            "handler" => fun_ref(
              method(:EditHandler),
              "boolean (map <string, string>)"
            )
          }
        },
        "options"    => {
          @HOSTNAME     => {
            "help"    => _("Used machine hostname"),
            "type"    => "string",
            "example" => "dns edit hostname=SUSE-host"
          },
          @NAMESERVER_1 => {
            "help"    => _("IP address of first nameserver."),
            "type"    => "string",
            "example" => "dns edit nameserver1=192.168.0.1"
          },
          @NAMESERVER_2 => {
            "help"    => _("IP address of second nameserver."),
            "type"    => "string",
            "example" => "dns edit nameserver2=192.168.0.1"
          },
          @NAMESERVER_3 => {
            "help"    => _("IP address of third nameserver."),
            "type"    => "string",
            "example" => "dns edit nameserver3=192.168.0.1"
          }
        },
        "mappings"   => {
          "edit" => [@HOSTNAME, @NAMESERVER_1, @NAMESERVER_2, @NAMESERVER_3]
        }
      }

      @ret = CommandLine.Run(@cmdline)
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("DNS module finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret)

      # EOF
    end

    # Return a modification status
    # @return true if data was modified
    def Modified
      DNS.modified
    end

    # Main DNS GUI
    def DNSGUI
      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("dns")
      DNS.Read
      Lan.Read(:cache)

      Wizard.SetNextButton(:next, Label.FinishButton)

      # main ui function
      ret = DNSMainDialog(true)
      Builtins.y2debug("ret == %1", ret)

      if ret == :next && DNS.modified
        DNS.Write
        # no more workarounds with dhcp-clients
        # do a full network restart (bnc#528937)
        NetworkService.StartStop
      end

      UI.CloseDialog
      deep_copy(ret)
    end

    # Handler for action "list"
    # @param _options [Hash{String => String}] action options
    def ListHandler(_options)
      # Command line output Headline
      summary = Ops.add(
        Ops.add(
          "\n" + _("DNS Configuration Summary:") + "\n\n",
          RichText.Rich2Plain(DNS.Summary)
        ),
        "\n"
      )

      Builtins.y2debug("%1", summary)
      CommandLine.Print(summary)
      true
    end

    # Handler for action "edit"
    # @param [Hash{String => String}] options action options
    # @return [Boolean] if successful
    def EditHandler(options)
      options = deep_copy(options)
      Builtins.y2milestone("Edit handler, options: %1", options)

      # validator: a reference to boolean( string) is expected
      # setter: a reference to void( any) is expected
      # fail message: a string is expected
      option_handlers = {
        @HOSTNAME     => {
          "validator"    => fun_ref(Hostname.method(:Check), "boolean (string)"),
          "setter"       => fun_ref(method(:SetHostname), "void (any)"),
          "fail_message" => Ops.add(_("InvalidHostname. "), Hostname.ValidHost)
        },
        @NAMESERVER_1 => {
          "validator"    => fun_ref(IP.method(:Check), "boolean (string)"),
          "setter"       => fun_ref(method(:SetNameserver1), "void (any)"),
          "fail_message" => Ops.add(
            Ops.add(Ops.add(_("Invalid IP. "), IP.Valid4), "\n"),
            IP.Valid6
          )
        },
        @NAMESERVER_2 => {
          "validator"    => fun_ref(IP.method(:Check), "boolean (string)"),
          "setter"       => fun_ref(method(:SetNameserver2), "void (any)"),
          "fail_message" => Ops.add(
            Ops.add(Ops.add(_("Invalid IP. "), IP.Valid4), "\n"),
            IP.Valid6
          )
        },
        @NAMESERVER_3 => {
          "validator"    => fun_ref(IP.method(:Check), "boolean (string)"),
          "setter"       => fun_ref(method(:SetNameserver3), "void (any)"),
          "fail_message" => Ops.add(
            Ops.add(Ops.add(_("Invalid IP. "), IP.Valid4), "\n"),
            IP.Valid6
          )
        }
      }

      unmanaged_only_options = [@NAMESERVER_1, @NAMESERVER_2, @NAMESERVER_3]

      ret = true

      Builtins.foreach(options) do |option, value|
        if Builtins.contains(unmanaged_only_options, option) &&
            NetworkService.is_network_manager
          CommandLine.Print(
            Ops.add(
              Ops.add(_("Cannot set "), option),
              _(". Network is managed by NetworkManager.")
            )
          )

          ret = false
        end
        option_validator = Convert.convert(
          Ops.get(option_handlers, [option, "validator"]),
          from: "any",
          to:   "boolean (string)"
        )
        option_setter = Convert.convert(
          Ops.get(option_handlers, [option, "setter"]),
          from: "any",
          to:   "void (any)"
        )
        fail_message = Ops.get_locale(
          option_handlers,
          [option, "fail_message"],
          _("Invalid option value.")
        )
        if option_validator.nil? || option_setter.nil?
          Builtins.y2internal(
            "Edit handler: unknown option (%1=%2) or unknown option handlers",
            option,
            value
          )

          CommandLine.Print(_("Internal error"))

          ret = false
        end
        if option_validator.call(value)
          option_setter.call(value)
        else
          CommandLine.Print(fail_message)
          ret = false
        end
      end

      ret
    end

    # CLI mode initialization handler
    # @return [Boolean] if successful
    def InitHandler
      return false if !DNS.Read || !Lan.Read(:cache)

      InitHnSettings()

      true
    end

    #  CLI mode finish handler
    # @return [Boolean] if successful
    def FinishHandler
      StoreHnSettings()

      DNS.Write
    end
  end
end

Yast::DnsClient.new.main
