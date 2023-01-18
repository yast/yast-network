# Copyright (c) [2023] SUSE LLC
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
require "y2storage"
require "cfa/generic_sysconfig"
require "y2network/helpers"
require "shellwords"

module Y2Network
  module Wicked
    # This class copies Wicked specific configuration to the target system
    class ConfigCopier
      include Yast::Logger
      include Y2Network::Helpers

      SYSCONFIG = "/etc/sysconfig/network".freeze
      WICKED_PATH = "/etc/wicked".freeze
      WICKED_DHCP_PATH = "/var/lib/wicked/".freeze
      WICKED_ENTRIES = [
        { dir: SYSCONFIG, files: ["ifcfg-*", "ifroute-*", "routes"] },
        { dir: WICKED_DHCP_PATH, files: ["duid.xml", "iaid.xml", "lease*.xml"] },
        { dir: WICKED_PATH, files: ["common.xml"] }
      ].freeze

      def copy
        adjust_files_for_network_disks!
        WICKED_ENTRIES.each { |e| copy_to_target(e[:dir], include: e[:files]) }
        merge_sysconfig_files
      end

    private

      # Convenience method for checking if the root filesystem is in network or not
      #
      # @return [Boolean] true if '/' filesystem is in network; false otherwise
      def root_filesystem_in_network?
        # storage-ng
        # Check if installation is targeted to a remote destination.
        devicegraph = Y2Storage::StorageManager.instance.staging
        if !devicegraph.filesystem_in_network?("/")
          log.info("Root filesystem is not on a network based device")
          return false
        end

        log.info("Root filesystem is on a network based device")
        true
      end

      # Sets the startmode of the given file to be 'nfsroot'
      #
      # @param file [String] ifcfg name
      def adjust_startmode!(file)
        return unless file.include?("ifcfg-")

        # tune ifcfg file for remote filesystem
        Yast::SCR.Execute(
          Yast::Path.new(".target.bash"),
          "/usr/bin/sed -i s/^[[:space:]]*STARTMODE=.*/STARTMODE='nfsroot'/ #{file.shellescape}"
        )
      end

      def adjust_files_for_network_disks!
        return unless root_filesystem_in_network?

        file_pattern = ::File.join(ROOT_PATH, SYSCONFIG, "ifcfg-*")
        Dir.glob(file_pattern).each { |f| adjust_startmode!(f) }
      end

      def merge_sysconfig_files
        copy_to = Yast::String.Quote(::File.join(inst_dir, SYSCONFIG))

        # merge files with default installed by sysconfig
        ["dhcp", "config"].each do |file|
          modified_file = ::File.join(ROOT_PATH, SYSCONFIG, file)
          dest_file = ::File.join(copy_to, file)
          if ::File.exist?(dest_file)
            CFA::GenericSysconfig.merge_files(dest_file, modified_file)
          else
            puts modified_file
            copy_to_target(modified_file)
          end
        end
      end
    end
  end
end
