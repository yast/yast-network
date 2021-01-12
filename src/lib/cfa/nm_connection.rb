# Copyright (c) [2021] SUSE LLC
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

require "cfa/base_model"

module CFA
  # Class to handle NetworkManager connection configuration files
  #
  # @example Reading the connection name
  #   file = NmConnection.new("/etc/NetworkManager/system-connections/eth0.nmconnection")
  #   file.load
  #   puts file.connection["id"]
  class NmConnection < BaseModel
    # Constructor
    #
    # @param path [String] File path
    # @param file_handler [.read, .write] Object to read/write the file.
    def initialize(path, file_handler: nil)
      super(AugeasParser.new("Networkmanager.lns"), path, file_handler: file_handler)
    end

    # Returns the augeas tree for the connection section
    #
    # If the "[connection]" section does not exist, it returns an empty one.
    #
    # @return [AugeasTree]
    def connection
      return data["connection"] if data["connection"]

      data["connection"] ||= CFA::AugeasTree.new
    end
  end
end
