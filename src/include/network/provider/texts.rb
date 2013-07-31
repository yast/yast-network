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
# File:	include/network/provider/texts.ycp
# Package:	Network configuration
# Summary:	Provider specific texts
# Authors:	Michal Svec <msvec@suse.cz>
#
module Yast
  module NetworkProviderTextsInclude
    def initialize_network_provider_texts(include_target)
      textdomain "network"

      # Provider specific texts

      @TEXTS = {
        # Custom provider text
        "kamp-dsl"             => _(
          "<p>Access to Kamp DSL.</p>"
        ) +
          # Custom provider text
          _(
            "<p>In the <b>User Name</b> field, replace the blank space\n" +
              "(after the <b>/</b>) with your Kamp login. Then enter your password\n" +
              "and click <b>Next</b>. Contact your provider if you have difficulties.</p>\n"
          ),
        # Custom provider text
        "aol-dsl"              => _(
          "<p>Access AOL-DSL.</p>"
        ) +
          # Custom provider text
          _(
            "<p>In the <b>User Name</b> field, replace the blank space (before\n" +
              "the <b>@</b>) with your AOL login. Then enter your password and click <b>Next</b>.\n" +
              "If you are a new AOL customer and want to dial up for the first time, you need\n" +
              "to enter your AOL PIN number once. If you have a Windows system, you can enter\n" +
              "the PIN in the AOL dial-up software. If not, call the AOL hot line and request\n" +
              "the AOL staff to enter the PIN number for you.</p>\n"
          ),
        # Custom provider text
        "einsundeins-dsl"      => _(
          "<p>Access to Kamp 1&1 DSL.</p>"
        ) +
          # Custom provider text
          _(
            "<p>In the <b>User Name</b> field, replace the blank space (after\n" +
              "the <b>/</b>) with your 1&1 login. Then enter your password and click <b>Next</b>.\n" +
              "Contact your provider if you have difficulties.</p>\n"
          ),
        # Custom provider text
        "eggenet-dsl"          => _(
          "<p>Access to Kamp Eggenet DSL.</p>"
        ) +
          # Custom provider text
          _(
            "<p>Enter your password and click <b>Next</b>.\nContact your provider if you have difficulties.</p>\n"
          ),
        # Custom provider text
        "tonline-dsl-business" => _(
          "<p>Access to Kamp T-Online Business DSL.</p>"
        ) +
          # Custom provider text
          _(
            "<p>In the <b>User Name</b> field, replace the blank space (after\n" +
              "the <b>/</b>) with your T-Online Business login. Then enter your password and\n" +
              "click <b>Next</b>. Contact your provider if you have difficulties.</p>\n"
          )
      } 

      # EOF
    end
  end
end
