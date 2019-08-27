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

require_relative "../../test_helper"
require "cwm/rspec"

require "y2network/widgets/udev_rules"
require "y2network/dialogs/rename_interface"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::UdevRules do
  subject { described_class.new(builder) }

  let(:builder) do
    instance_double(Y2Network::InterfaceConfigBuilder, interface: double(can_be_renamed?: true))
  end

  before do
    allow(Yast::LanItems).to receive(:current_udev_name).and_return("hell666")
    allow(Y2Network::Dialogs::RenameInterface).to receive(:new).and_return(double(run: "heaven010"))
  end

  include_examples "CWM::CustomWidget"
end
