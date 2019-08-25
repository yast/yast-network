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

require "y2network/widgets/custom_interface_name"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::CustomInterfaceName do
  subject { described_class.new(builder) }

  let(:builder) do
    instance_double(
      Y2Network::InterfaceConfigBuilder,
      name:         "eth",
      valid_name?:  valid_name?,
      name_exists?: name_exists?
    )
  end
  let(:valid_name?) { true }
  let(:name_exists?) { false }

  include_examples "CWM::InputField"

  describe "#validate" do

    before do
      allow(builder)
    end

    context "when the name is valid" do
      it "returns true" do
        expect(subject.validate).to eq(true)
      end
    end

    context "when the name contains unexpected characters" do
      let(:valid_name?) { false }

      it "returns false" do
        expect(subject.validate).to eq(false)
      end

      it "displays an error popup" do
        expect(Yast::Popup).to receive(:Error).with(/Invalid configuration/)
        subject.validate
      end
    end

    context "when the name is already taken" do
      let(:name_exists?) { true }

      it "returns false" do
        expect(subject.validate).to eq(false)
      end

      it "displays an error popup" do
        expect(Yast::Popup).to receive(:Error).with(/already exists/)
        subject.validate
      end
    end
  end
end
