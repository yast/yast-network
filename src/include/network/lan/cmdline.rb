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
# File:  lan/cmdline.ycp
# Package:  Network configuration
# Summary:  Network cards cmdline handlers
# Authors:  Michal Svec <msvec@suse.cz>
#

require "shellwords"
require "y2network/interface_config_builder"
require "y2network/boot_protocol"
require "y2network/presenters/interface_summary"

module Yast
  module NetworkLanCmdlineInclude
    include Yast::Logger

    def initialize_network_lan_cmdline(_include_target)
      textdomain "network"

      Yast.import "CommandLine"
      Yast.import "Lan"
      Yast.import "Report"
      Yast.import "LanItems"
    end

    def validateId(options, config)
      if !options["id"]
        Report.Error(_("Use \"id\" option to determine device."))
        return false
      end

      begin
        id = Integer(options["id"])
      rescue ArgumentError
        Report.Error(_("Invalid value '%s' for \"id\" option.") % options["id"])
        return false
      end

      if id >= config.size
        Report.Error(
          _("Value of \"id\" is out of range. Use \"list\" option to check max. value of \"id\".")
        )
        return false
      end
      true
    end

    # Handler for action "show"
    # @param [Hash{String => String}] options action options
    def ShowHandler(options)
      config = Yast::Lan.yast_config
      return false unless validateId(options, config.interfaces)

      presenter = Y2Network::Presenters::InterfaceSummary.new(
        config.interfaces.to_a[options["id"].to_i].name, config
      )
      text = presenter.text
      # create plain text from formated HTML
      text.gsub!(/(<br>)|(<\/li>)/, "\n")
      text.gsub!(/<[^>]+>/, "")
      CommandLine.Print(text)

      true
    end

    def ListHandler(options)
      config = Yast::Lan.yast_config
      CommandLine.Print("id\tname\tbootproto")
      config.interfaces.to_a.each_with_index do |interface, index|
        connection = config.connections.by_name(interface.name)
        next if connection && options.include?("unconfigured")
        next if !connection && options.include?("configured")

        status = if !connection
          "Not configured"
        elsif connection.bootproto == Y2Network::BootProtocol::STATIC
          connection.ip.address.to_s
        else
          connection.bootproto.name
        end
        CommandLine.Print(
          "#{index}\t#{interface.name}\t#{status}"
        )
      end
      true
    end

    # Handler for action "add"
    # @param [Hash{String => String}] options action options
    def AddHandler(options)
      type = options.fetch("type", infered_type(options))
      if type.empty?
        Report.Error(_("The device type is mandatory."))
        return false
      end

      builder = Y2Network::InterfaceConfigBuilder.for(
        Y2Network::InterfaceType.from_short_name(type)
      )
      builder.name = options.fetch("name")
      update_builder_from_options!(builder, options)

      LanItems.Commit(builder)
      ListHandler({})

      true
    rescue InvalidOption => e
      Report.Error(e.message)
      false
    end

    # Handler for action "edit"
    # @param [Hash{String => String}] options action options
    def EditHandler(options)
      log.info "calling edit handler with #{options}"
      config = Lan.yast_config.copy

      return false unless validateId(options, config.interfaces)

      interface = config.interfaces.to_a[options["id"].to_i]

      connection_config = config.connections.by_name(interface.name)
      builder = Y2Network::InterfaceConfigBuilder.for(interface.type, config: connection_config)
      builder.name = interface.name
      update_builder_from_options!(builder, options)

      LanItems.Commit(builder)
      ShowHandler(options)
      true
    rescue InvalidOption => e
      Report.Error(e.message)
      false
    end

    # Handler for action "delete"
    # @param [Hash{String => String}] options action options
    def DeleteHandler(options)
      config = Yast::Lan.yast_config
      return false unless validateId(options, config.interfaces)

      interface = config.interfaces.to_a[options["id"].to_i]

      config.delete_interface(interface.name)

      true
    end

  private

    # Return the infered type from the given options or an empty string if no
    # one infered.
    #
    # @param options [Hash{String => String}] action options
    # @return [String] infered device type; an empty string if not infered
    def infered_type(options)
      return "bond" if options.include? "slaves"
      return "vlan" if options.include? "ethdevice"
      return "br"   if options.include? "bridge_ports"

      ""
    end

    def check_boot_protocol(boot_protocol)
      return if Y2Network::BootProtocol.from_name(boot_protocol)

      message = _("Invalid value for bootproto. Possible values: ")
      message += Y2Network::BootProtocol.all.map(&:name).join(", ")
      log.warn "Invalid boot protocol #{boot_protocol}"
      raise InvalidOption, message
    end

    def check_startmode(startmode)
      return if Y2Network::Startmode.create(startmode)

      message = _("Invalid value for startmode. Possible values: ")
      message += Y2Network::Startmode.all.map(&:name).join(", ")
      log.warn "Invalid startmode #{startmode}"
      raise InvalidOption, message
    end

    # Convenience method to update the builder internal state taking in account
    # the given options
    #
    # @param builder [Y2Network::InterfaceConfigBuilder]
    # @param options [Hash{String => String}] action options
    def update_builder_from_options!(builder, options)
      case builder.type.short_name
      when "bond"
        # change only if user specify it
        builder.slaves = options["slaves"].split(" ") if options["slaves"]
      when "vlan"
        # change only if user specify it
        builder.etherdevice = options["ethdevice"] if options["ethdevice"]
      when "br"
        # change only if user specify it
        builder.ports = options["bridge_ports"] if options["bridge_ports"]
      end

      default_bootproto = options.keys.include?("ip") ? "static" : "none"
      boot_protocol = options.fetch("bootproto", default_bootproto)
      # check for valid value
      check_boot_protocol(boot_protocol)
      builder.boot_protocol = boot_protocol
      if builder.boot_protocol.name == "static"
        ip_address = options.fetch("ip", "")
        if ip_address.empty?
          raise InvalidOption, _("For static configuration, the \"ip\" option is needed.")
        end

        builder.ip_address = ip_address
        builder.subnet_prefix = options.fetch("prefix", options.fetch("netmask", "255.255.255.0"))
      else
        builder.ip_address = ""
        builder.subnet_prefix = ""
      end
      startmode = options.fetch("startmode", "auto")
      check_startmode(startmode)
      builder.startmode = startmode
    rescue IPAddr::InvalidAddressError => e
      log.warn "Invalid address #{e.inspect}"
      raise InvalidOption, _("Invalid ip address, prefix or netmask")
    end

    # exception for invalid options
    class InvalidOption < RuntimeError
    end
  end
end
