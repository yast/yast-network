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
  # An Interface corresponding to a physical device (ethernet card, ...)
  #
  # Main difference is that
  # 1) it can have a configuration assigned or not and we need to track both cases
  # 2) such devices can be renamed via udev
  class HwInterface < Interface
    attr_reader :hw_name

    def initialize(name, hw_name:)
      if !name && !hw_name
        raise ArgumentError, "Configuration name or Hardware name has to be defined"
      end

      super(name)

      @hw_name = hw_name
      @configured = !name.nil?
    end

    def name
      name || hw_name
    end
  end
end
