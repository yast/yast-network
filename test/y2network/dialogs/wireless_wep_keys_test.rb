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

require "y2network/dialogs/wireless_wep_keys"
require "y2network/interface_config_builder"

describe Y2Network::Dialogs::WirelessWepKeys do
  subject { described_class.new(Y2Network::InterfaceConfigBuilder.for("wlan")) }

  include_examples "CWM::Dialog"
end

describe Y2Network::Dialogs::WirelessWepKeys::WEPKeyLength do
  subject { described_class.new(Y2Network::InterfaceConfigBuilder.for("wlan")) }

  include_examples "CWM::ComboBox"
end

describe Y2Network::Dialogs::WirelessWepKeys::WEPKeys do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"

  describe "#handle" do
    it "opens wep key dialog for edit button" do
      builder.keys = ["test"]
      expect(Yast::UI).to receive(:UserInput).and_return(:cancel)

      subject.handle("EventReason" => "Activated", "ID" => :wep_keys_edit)
    end

    it "opens wep key dialog for add button" do
      expect(Yast::UI).to receive(:UserInput).and_return(:cancel)

      subject.handle("EventReason" => "Activated", "ID" => :wep_keys_add)
    end
  end
end
