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

module Y2Network
  module Helpers
    include Yast::Logger

    ROOT_PATH = "/".freeze

    def inst_dir
      Yast::Installation.destdir
    end

    # Convenvenience method for copying a list of files into the target system.
    # It takes care of creating the target directory but only if some file
    # needs to be copied
    #
    # @param path [String] path where the files resides and where will be
    # copied in the target system
    # @return [Boolean] whether some file was copied
    def copy_to_target(path, include: nil, target: inst_dir)
      dest_path = ::File.join(target, path)
      files = if include
        include.map { |f| File.join(ROOT_PATH, path, f) }
      else
        File.join(ROOT_PATH, path)
      end
      glob_files = ::Dir.glob(files)
      return false if glob_files.empty?

      log.info("Copying '#{glob_files.join(",")}' to '#{dest_path}'.")

      ::FileUtils.mkdir_p(include ? dest_path : dest_path.dirname)
      ::FileUtils.cp(glob_files, dest_path, preserve: true)
      true
    end
  end
end
