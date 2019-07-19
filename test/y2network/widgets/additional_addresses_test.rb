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

require "y2network/widgets/additional_addresses"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::AdditionalAddresses do
  subject { described_class.new(Y2Network::InterfaceConfigBuilder.for("eth")) }

  include_examples "CWM::CustomWidget"

  describe "#handle" do
    it "opens address dialog for edit address button" do
      expect(Yast::UI).to receive(:UserInput).and_return(:cancel)

      subject.handle("EventReason" => "Activated", "ID" => :edit_address)
    end

    it "opens address dialog for add address button" do
      expect(Yast::UI).to receive(:UserInput).and_return(:cancel)

      subject.handle("EventReason" => "Activated", "ID" => :add_address)
    end

    it "do validations in address dialog" do
      expect(Yast::UI).to receive(:UserInput).and_return(:ok)
      allow(Yast::UI).to receive(:QueryWidget)
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:name), :Value).and_return("test")
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:ipaddr), :Value).and_return("10.0.0.1")
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:netmask), :Value).and_return("/24")

      subject.handle("EventReason" => "Activated", "ID" => :add_address)
    end
  end
end
