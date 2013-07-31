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
# File:	include/network/provider/helps.ycp
# Package:	Network configuration
# Summary:	Provider dialog helps
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkProviderHelpsInclude
    def initialize_network_provider_helps(include_target)
      textdomain "network"

      # Provider dialog help texts

      @HELPS = {
        # Provider read dialog help 1/2
        "read"      => _(
          "<p><b><big>Initializing Provider\nConfiguration</big></b><br>Please wait...<br></p>\n"
        ) +
          # Provider read dialog help 2/2
          _(
            "<p><b><big>Aborting the Initialization:</big></b><br>\nSafely abort the configuration utility by pressing <B>Abort</B> now.</p>\n"
          ),
        # Provider write dialog help 1/2
        "write"     => _(
          "<p><b><big>Saving Provider\nConfiguration</big></b><br>Please wait...<br></p>\n"
        ) +
          # Provider write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving:</big></b><br>\nAbort saving by pressing <b>Abort</b>.</p>\n"
          ),
        # Provider summary dialog help 1/3
        "summary"   => _(
          "<p><b><big>Provider Setup</big></b><br>\nConfigure your provider here.<br></p>\n"
        ) +
          # Provider summary dialog help 2/3
          _(
            "<p><b><big>Adding a Provider:</big></b><br>\n" +
              "Choose a provider from the list of available providers\n" +
              "then press <b>Edit</b>.</p>\n"
          ) +
          # Provider summary dialog help 3/3
          _(
            "<p><b><big>Editing or Deleting:</big></b><br>\n" +
              "If you press <b>Edit</b>, an additional dialog in which\n" +
              "to change the configuration opens.</p>\n"
          ),
        # Provider overview dialog help 1/3
        "overview"  => _(
          "<p><b><big>Provider Overview</big></b><br>\n" +
            "Obtain an overview of installed providers. Additionally,\n" +
            "edit their configurations.<br></p>\n"
        ) +
          # Provider overview dialog help 2/3
          _(
            "<p><b><big>Adding a Provider:</big></b><br>\nPress <b>Add</b> to configure a new provider manually.</p>\n"
          ) +
          # Provider overview dialog help 3/3
          _(
            "<p><b><big>Editing or Deleting:</big></b><br>\n" +
              "Choose a provider to change or remove.\n" +
              "Then press <b>Edit</b> or <b>Delete</b> as desired.</p>\n"
          ),
        # Provider dialog help 1/3
        "providers" => _(
          "<p>Select the appropriate <b>provider</b>.</p>"
        ) +
          # Provider dialog help 2/3
          _(
            "<p>Choose the country or region where you are\nlocated then choose one of the listed providers.</p>"
          ) +
          # Provider dialog help 3/3
          _("<p>Use <b>New</b> to add a provider not in the list.</p>"),
        # Provider type dialog help 1/1
        "type"      => _(
          "<p>Choose one of the available provider types.</p>"
        )
      } 

      # EOF
    end
  end
end
