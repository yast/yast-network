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

Yast.import "Installation"

module Y2Network
  # This class is responsible for copying the backend specific configuration to the target system
  #
  # It is expect that a configuration copier exists for each supported backend
  # by inheriting from this class.
  class ConfigCopier
    include Yast::Logger
    include Yast::I18n

    ETC = "/etc/".freeze
    ROOT_PATH = "/".freeze

    class << self
      # Returns a configuration writer for a given source
      #
      # @param source [Symbol] Source name (e.g., :wicked)
      # @return [Y2Network::ConfigCopier]
      #
      # @see Y2Network::ConfigCopier
      def for(source)
        require "y2network/#{source}/config_copier"
        modname = source.to_s.split("_").map(&:capitalize).join
        klass = Y2Network.const_get("#{modname}::ConfigCopier")
        klass.new
      end
    end

    # Copies the configuration to the target system
    def copy; end

  private

    def inst_dir
      Yast::Installation.destdir
    end

    # Convenvenience method for copying a list of files into the target system.
    # It takes care of creating the target directory but only if some file
    # needs to be copied
    #
    # @param files [Array<String>] list of short filenames to be copied
    # @param path [String] path where the files resides and where will be
    # copied in the target system
    # @return [Boolean] whether some file was copied
    def copy_files_to_target(files, path)
      dest_dir = ::File.join(Yast::Installation.destdir, path)
      glob_files = ::Dir.glob(files.map { |f| File.join(ROOT_PATH, path, f) })
      return false if glob_files.empty?

      log.info("Copying '#{glob_files.join(",")}' to '#{dest_dir}'.")

      ::FileUtils.mkdir_p(dest_dir)
      ::FileUtils.cp(glob_files, dest_dir, preserve: true)
      true
    end
  end
end
