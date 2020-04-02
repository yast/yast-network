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

require_relative "../../test_helper"
require "y2network/config"
require "y2network/autoinst_profile/s390_device_section"
require "y2network/autoinst/s390_devices_reader"

describe Y2Network::Autoinst::S390DevicesReader do
  let(:subject) { described_class.new(s390_section) }
  let(:s390_section) do
    Y2Network::AutoinstProfile::S390DevicesSection.new_from_hashes(s390_profile)
  end

  let(:system_config) { Y2Network::Config.new(source: :testing) }

  let(:eth0) do
    {
      "chanids" => "0.0.0700 0.0.0701 0.0.0702",
      "type"    => "qeth"
    }
  end

  let(:eth1) do
    {
      "chanids" => "0.0.0800 0.0.0801 0.0.0802",
      "type"    => "qeth",
      "layer2"  => true
    }
  end

  let(:s390_profile) { [eth0, eth1] }

  describe "#config" do
    it "builds a new Y2Network::ConnectionConfigsCollection" do
      expect(subject.config).to contain_exactly(
        an_object_having_attributes(
          read_channel:  "0.0.0700",
          write_channel: "0.0.0701",
          data_channel:  "0.0.0702"
        ),
        an_object_having_attributes(
          read_channel:  "0.0.0800",
          write_channel: "0.0.0801",
          data_channel:  "0.0.0802",
          layer2:        true
        )
      )
    end
  end
end
