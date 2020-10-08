# Copyright (c) [2020] SUSE LLC
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
require "y2network/config"

Yast.import "DNS"
Yast.import "Label"
Yast.import "Lan"
Yast.import "NetworkService"
Yast.import "Wizard"

Yast.import "CommandLine"
Yast.import "RichText"

module Y2Network
  module Clients
    # DNS client for configuring DNS and hostname settings
    class DNS < Yast::Client
      include Yast::Logger

      attr_reader :hostname, :nameserver1, :nameserver2, :nameserver3

      # Constructor
      def initialize
        textdomain "network"
        Yast.include self, "network/services/dns.rb"

        @hostname = "hostname"
        @nameserver1 = "nameserver1"
        @nameserver2 = "nameserver2"
        @nameserver3 = "nameserver3"
      end

      def main
        log_and_return { CommandLine.Run(cmdline_definition) }
      end

    private

      # Main DNS GUI
      def DNSGUI
        Wizard.CreateDialog
        Wizard.SetDesktopTitleAndIcon("dns")
        read_config

        Wizard.SetNextButton(:next, Label.FinishButton)

        # main ui function
        ret = DNSMainDialog(true)
        log.debug("ret == #{ret}")

        if (ret == :next) && modified?
          write_config

          # no more workarounds with dhcp-clients
          # do a full network restart (bnc#528937)
          Yast::NetworkService.StartStop
        end

        UI.CloseDialog
        ret
      end

      def modified?
        Yast::Lan.system_config != Yast::Lan.yast_config
      end

      def valid_hostname?(value)
        value.empty? || Yast::Hostname.Check(value.tr(".", ""))
      end

      def config
        Yast::Lan.yast_config
      end

      def log_and_return(&block)
        # The main ()
        log.info("----------------------------------------")
        log.info("Dns module started")
        ret = block.call
        # Finish
        log.info("Dns module finished with ret=#{ret.inspect}")
        log.info("----------------------------------------")
        ret
      end

      def cmdline_definition
        {
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
            hostname    => {
              "help"    => _("Used machine hostname"),
              "type"    => "string",
              "example" => "dns edit hostname=SUSE-host"
            },
            nameserver1 => {
              "help"    => _("IP address of first nameserver."),
              "type"    => "string",
              "example" => "dns edit nameserver1=192.168.0.1"
            },
            nameserver2 => {
              "help"    => _("IP address of second nameserver."),
              "type"    => "string",
              "example" => "dns edit nameserver2=192.168.0.1"
            },
            nameserver3 => {
              "help"    => _("IP address of third nameserver."),
              "type"    => "string",
              "example" => "dns edit nameserver3=192.168.0.1"
            }
          },
          "mappings"   => {
            "edit" => [hostname, nameserver1, nameserver2, nameserver3]
          }
        }
      end

      def option_handlers
        {
          hostname    => {
            "validator"    => fun_ref(method(:valid_hostname?), "boolean (string)"),
            "setter"       => fun_ref(method(:SetHostname), "void (any)"),
            "fail_message" => Ops.add(_("InvalidHostname. "), Yast::Hostname.ValidHost)
          },
          nameserver1 => {
            "validator"    => fun_ref(Yast::IP.method(:Check), "boolean (string)"),
            "setter"       => fun_ref(method(:SetNameserver1), "void (any)"),
            "fail_message" => Ops.add(
              Ops.add(Ops.add(_("Invalid IP. "), Yast::IP.Valid4), "\n"),
              Yast::IP.Valid6
            )
          },
          nameserver2 => {
            "validator"    => fun_ref(Yast::IP.method(:Check), "boolean (string)"),
            "setter"       => fun_ref(method(:SetNameserver2), "void (any)"),
            "fail_message" => Ops.add(
              Ops.add(Ops.add(_("Invalid IP. "), Yast::IP.Valid4), "\n"),
              Yast::IP.Valid6
            )
          },
          nameserver3 => {
            "validator"    => fun_ref(IP.method(:Check), "boolean (string)"),
            "setter"       => fun_ref(method(:SetNameserver3), "void (any)"),
            "fail_message" => Ops.add(
              Ops.add(Ops.add(_("Invalid IP. "), IP.Valid4), "\n"),
              IP.Valid6
            )
          }
        }
      end

      # Handler for action "list"
      # @param _options [Hash{String => String}] action options
      def ListHandler(_options)
        dns_summary =
          Yast::RichText.Rich2Plain(Y2Network::Presenters::Summary.for(config, "dns").text)
        summary = "\n" + _("DNS Configuration Summary:") + "\n" + dns_summary + "\n"

        log.debug(summary)
        Yast::CommandLine.Print(summary)

        true
      end

      # Handler for action "edit"
      # @param [Hash{String => String}] options action options
      # @return [Boolean] if successful
      def EditHandler(options)
        log.info("Edit handler, options: #{options.inspect}")

        # validator: a reference to boolean( string) is expected
        # setter: a reference to void( any) is expected
        # fail message: a string is expected

        unmanaged_only_options = [nameserver1, nameserver2, nameserver3]

        ret = true

        options.each do |option, value|
          if unmanaged_only_options.include?(option) && Yast::NetworkService.is_network_manager
            error_message = _("Cannot set ") + option + _(". Network is managed by NetworkManager.")
            Yast::CommandLine.Print(error_message)

            ret = false
          end
          option_validator = option_handlers.fetch(option, {}).fetch("validator")
          option_setter = option_handlers.fetch(option, {}).fetch("setter")
          fail_message = Ops.get_locale(
            option_handlers,
            [option, "fail_message"],
            _("Invalid option value.")
          )

          if option_validator.nil? || option_setter.nil?
            log.info("Edit handler: unknown option or handler for (#{option}=#{value})")

            Yast::CommandLine.Print(_("Internal error"))

            ret = false
          end

          if option_validator.call(value)
            option_setter.call(value)
          else
            Yast::CommandLine.Print(fail_message)
            ret = false
          end
        end

        ret
      end

      # CLI mode initialization handler
      # @return [Boolean] if successful
      def InitHandler
        return false if !read_config

        InitHnSettings()

        true
      end

      #  CLI mode finish handler
      # @return [Boolean] if successful
      def FinishHandler
        StoreHnSettings()

        write_config if modified?

        true
      end

      def read_config
        Yast::Lan.Read(:cache)
      end

      def write_config
        Yast::Lan.write_config(sections: [:dns, :hostname])
      end
    end
  end
end
