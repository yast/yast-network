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
  # FIXME: should read hwinfo for a network device and store only necessary info
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

    def mac
      @hwinfo ? @hwinfo.fetch("mac", "") : ""
    end

    def busid
      @hwinfo ? @hwinfo.fetch("busid", "") : ""
    end

    def name
      @hwinfo ? @hwinfo.fetch("dev_name", "") : ""
    end
  end
end
