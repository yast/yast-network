# ***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
# **************************************************************************
# File:  include/network/complex.ycp
# Package:  Network configuration
# Summary:  Summary and overview functions
# Authors:  Michal Svec <msvec@suse.cz>
#
#
module Yast
  module NetworkComplexInclude
    def initialize_network_complex(include_target)
      Yast.import "UI"

      textdomain "network"

      Yast.import "NetworkInterfaces"

      Yast.include include_target, "network/routines.rb"
    end

    # TODO: move to HTML.ycp
    def Hyperlink(href, text)
      Builtins.sformat("<a href=\"%1\">%2</a>", href, text)
    end

    def HardwareName(hardware, id)
      return "" if id.nil? || id.empty?
      return "" if hardware.nil? || hardware.empty?

      # filter out a list of hwinfos which correspond to the given id
      res_list = hardware.select do |h|
        have = [
          "id-" + (h["mac"] || ""),
          "bus-" + (h["bus"] || "") + "-" + (h["busid"] || ""),
          h["udi"] || "",
          h["dev_name"] || ""
        ]

        have.include?(id)
      end

      # take first item from the list - there should be just one
      if res_list.empty?
        Builtins.y2warning("HardwareName: no matching hardware for id=#{id}")

        return ""
      else
        hwname = res_list.first["name"] || ""
        Builtins.y2milestone("HardwareName: hwname=#{hwname} for id=#{id}")

        return hwname
      end
    end
  end
end
