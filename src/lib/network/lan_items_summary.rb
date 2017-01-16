# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "yast"

module Yast
  # This class creates a summary of the configured lan items supporting
  # different types of summaries.
  #
  # @example
  #   LanItemsSummary.new.summary
  #   => "<ul><li><p>eth0<br>DHCP</p></li><li><p>eth1<br>NONE</p></li></ul>"
  # @example
  #   LanItemsSummary.new(:type => 'one_line').summary
  #   => "Multiple Interfaces"
  class LanItemsSummary
    attr_accessor :summary_type, :options

    def initialize(options = {})
      Yast.import "LanItems"
      Yast.import "Summary"

      @summary_type =
        case options[:type]
        when "", nil
          Default
        when "one_line"
          OneLine
        else
          raise NotImplementedError,
            "The LanItems summary #{options[:type]} has not been implemented yet"
        end
      @options = options.reject { |k, _| k == :type }
    end

    # Delegates the summary to the specific class depending on the specific.
    # Uses Default if no type is given.
    def summary
      @summary_type.send(:new, @options).summary
    end

    class Base
      include I18n

      attr_accessor :options

      def initialize(options)
        @options = options
      end
    end

    # This class generates a one line text summary.
    class OneLine < Base
      def initialize(options = {})
        @options = options
      end

      def summary
        protocols  = []
        configured = []
        output     = []

        Yast::LanItems.Items.each do |item, conf|
          next if !LanItems.IsItemConfigured(item)

          ifcfg = LanItems.GetDeviceMap(item) || {}

          protocol = LanItems.DeviceProtocol(ifcfg)

          protocols <<
            if protocol =~ /DHCP/
              "DHCP"
            elsif IP.Check(protocol)
              "STATIC"
            else
              LanItems.DeviceProtocol(ifcfg)
            end

          configured << conf["ifcfg"]
        end

        output << protocols.first if protocols.uniq.size == 1

        case configured.size
        when 0
          _("Not configured yet.")
        when 1
          output << configured.first
        else
          output << "Multiple Interfaces"
        end

        output.join(" / ")
      end
    end

    # This class is the default summary using RichText format
    class Default < Base
      def summary
        items = []

        LanItems.Items.each do |item, conf|
          next if !Yast::LanItems.IsItemConfigured(item)

          ifcfg = LanItems.GetDeviceMap(item) || {}
          protocol = LanItems.DeviceProtocol(ifcfg)

          items << Summary.Device(conf["ifcfg"], protocol)
        end

        Summary.DevicesList(items)
      end
    end
  end
end
