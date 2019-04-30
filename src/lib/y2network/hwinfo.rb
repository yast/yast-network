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

module Y2Network
  # Stores useful (from networking POV) items of hwinfo for an interface
  # FIXME: decide whether it should read hwinfo (on demand or at once) for a network
  # device and store only necessary info or just parse provided hash
  class Hwinfo
    attr_reader :hwinfo

    def initialize(name:)
      # FIXME: store only what's needed.
      @hwinfo = load_hwinfo(name)
    end

    # Shortcuts for accessing hwinfo items
    [
      { name: "dev_name", default: "" },
      { name: "mac", default: "" },
      { name: "busid", default: "" },
      { name: "link", default: false },
      { name: "driver", default: "" },
      { name: "drivers", default: [] },
      { name: "requires", default: [] },
      { name: "hotplug", default: false },
      { name: "wl_auth_modes", default: "" },
      { name: "wl_enc_modes", default: nil },
      { name: "wl_channels", default: nil },
      { name: "wl_bitrates", default: nil }
    ].each do |hwinfo_item|
      define_method hwinfo_item[:name].downcase do
        self.hwinfo ? self.hwinfo.fetch(hwinfo_item[:name], hwinfo_item[:default]) : hwinfo_item[:default]
      end
    end
    alias_method :name, :dev_name

    def exists?
      !@hwinfo.nil?
    end

    # Device type description
    # FIXME: collision with alias for dev_name
    def description
      @hwinfo ? @hwinfo.fetch("name", "") : ""
    end

  private

    # for textdomain in network/hardware.rb
    include Yast::I18n

    def load_hwinfo(name)
      Yast.include self, "network/hardware.rb"
      ReadHardware("netcard").find { |h| h["dev_name"] == name }
    end
  end
end
