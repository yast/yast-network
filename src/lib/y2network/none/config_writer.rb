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

require "y2network/wicked/config_writer"

module Y2Network
  module None
    # By now this class configures Wicked (through sysconfig) according to a
    # given configuration.
    #
    # TODO: Determine which configuration makes sense to be written when no
    # service will be enable disabling the rest in the different dialogs.
    class ConfigWriter < Y2Network::Wicked::ConfigWriter
    end
  end
end
