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
module Y2Network
  # Stores useful (from networking POV) items of hwinfo for an interface
  # FIXME: decide whether it should read hwinfo (on demand or at once) for a network
  # device and store only necessary info or just parse provided hash
  class Hwinfo
    def initialize(hwinfo: nil)
      # FIXME: store only what's needed.
      @hwinfo = hwinfo
    end

    def exists?
      !@hwinfo.nil?
    end

    def link?
      @hwinfo ? @hwinfo.fetch("link", false) : false
    end

    def name
      @hwinfo ? @hwinfo.fetch("dev_name", "") : ""
    end

    # Device type description
    def description
      @hwinfo ? @hwinfo.fetch("name", "") : ""
    end

    def mac
      @hwinfo ? @hwinfo.fetch("mac", "") : ""
    end

    def busid
      @hwinfo ? @hwinfo.fetch("busid", "") : ""
    end
  end
end
