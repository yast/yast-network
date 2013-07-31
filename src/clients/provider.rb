# encoding: utf-8

#***************************************************************************
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
#**************************************************************************
# File:	clients/provider.ycp
# Package:	Network configuration
# Summary:	Provider main file
# Authors:	Michal Svec <msvec@suse.cz>
#
#
# Main file for provider configuration.
# Uses all other files.
module Yast
  class ProviderClient < Client
    def main
      Yast.import "UI"

      textdomain "network"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Provider module started")

      Yast.import "Provider"

      Yast.include self, "network/provider/wizards.rb"

      # is this proposal or not?
      @propose = false
      @args = WFM.Args
      if Ops.greater_than(Builtins.size(@args), 0)
        if Ops.is_path?(WFM.Args(0)) && WFM.Args(0) == path(".propose")
          Builtins.y2milestone("Using PROPOSE mode")
          @propose = true
        else
          Builtins.y2error("Bad argument for providers: %1", WFM.Args(0))
        end
      end

      # main ui function
      @ret = nil

      if @propose
        @ret = ProviderAutoSequence()
      else
        @ret = ProviderSequence()
      end
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Provider module finished")
      Builtins.y2milestone("----------------------------------------")
      deep_copy(@ret) 

      # EOF
    end

    def Modified
      Provider.Modified("all")
    end
  end
end

Yast::ProviderClient.new.main
