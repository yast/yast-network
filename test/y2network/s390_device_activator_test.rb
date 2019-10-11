#!/usr/bin/env rspec

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

require_relative "../test_helper"

require "y2network/s390_device_activator"
require "y2network/interface_config_builder"

describe Y2Network::S390DeviceActivator do
  let(:logger) { double(info: true) }
  let(:known_builder) { Y2Network::InterfaceConfigBuilder.for("qeth") }
  let(:unknown_builder) { Y2Network::InterfaceConfigBuilder.for("dummy") }

  describe ".for" do
    context "specialized class for given known builder" do
      it "returns new instance of that class" do
        expect(described_class.for(known_builder).class.to_s).to eq "Y2Network::S390DeviceActivators::Qeth"
      end
    end

    context "specialized class for given builder does NOT exist" do
      before do
        allow(described_class).to receive(:log).and_return(logger)
      end

      it "returns nil" do
        expect(described_class.for(unknown_builder)).to be_nil
      end

      it "logs the error" do
        expect(logger).to receive(:info).with(/Specialized device activator for dummy not found/)
        described_class.for(unknown_builder)
      end
    end
  end
end
