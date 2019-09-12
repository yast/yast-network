# Copyright (c) [2019] SUSE LLC
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
require "y2network/autoinst_profile/udev_rule_section"

module Y2Network
  module Autoinst
    # This class is responsible of importing the AutoYast udev rules section
    # It is a bit different then other readers as it does not produce its config,
    # but instead it is applied on top of current config by applying proper names
    # for interfaces or creating new ones.
    class UdevRulesReader
      include Yast::Logger

      # @return [AutoinstProfile::UdevRulesSection]
      attr_reader :section

      # @param section [AutoinstProfile::UdevRulesSectionSection]
      def initialize(section)
        @section = section
      end

      # Apply udev rules on passed config
      # @param config [Config]
      def apply(config)
        @section.udev_rules.each do |udev_rule|
          target_interface = interface_for(config, udev_rule)
          if target_interface
            rename_interface(config, target_interface, udev_rule)
          else
            create_interface(config, udev_rule)
          end
        end
      end

    private

      # find according to udev rule interface that match given hardware specification or nil if not exist
      def interface_for(config, udev_rule)
        config.interfaces.find do |interface|
          next unless interface.hardware

          hw_method = AutoinstProfile::UdevRulesSectionSection::VALUE_MAPPING[udev_rule.rule]
          interface.hardware.public_send(hw_method) == udev_rule.value
        end
      end

      def rename_interface(config, target_interface, udev_rule)
        solve_collision(config, target_interface, udev_rule)

        old_name = target_interface.name == udev_rule.name ? nil : target_interface.name
        mechanism = AutoinstProfile::UdevRulesSectionSection::RULE_MAPPING[udev_rule.rule]
        config.rename_interface(old_name, udev_rule.name, mechanism)
      end

      def create_interface(_config, udev_rule)
        log.error "Cannot find interface to apply udev rule #{udev_rule.inspect}. Skipping ..."
      end

      def solve_collision(config, target_interface, udev_rule)
        existing_interface = config.interfaces.by_name(udev_rule.name)
        return unless existing_interface
        return if existing_interface == target_interface

        prefix = existing_interface.name[/\A(.*[^\d])\d+\z/, 1]
        new_name = config.interfaces.new_name(prefix)

        # TODO: what mechanism should be default?
        config.rename_interface(existing_interface.name, new_name, :mac)
      end
    end
  end
end
