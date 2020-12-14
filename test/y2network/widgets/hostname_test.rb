# Copyright (c) [2020] SUSE LLC
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

require "y2network/widgets/hostname"

describe Y2Network::Widgets::Hostname do
  let(:initial_hostname) { "example.suse.com" }
  let(:settings) { Struct.new(:hostname).new(initial_hostname) }

  subject { described_class.new(settings) }

  include_examples "CWM::InputField"

  describe "#init" do
    it "initializes the input with the given object hostname" do
      expect(subject).to receive("value=").with(initial_hostname)

      subject.init
    end
  end

  describe "#validate" do
    it "return true when the input is a valid hostname" do
      allow(subject).to receive(:value).and_return(initial_hostname)
      expect(subject.validate).to eql(true)
    end

    it "returns false if the input is an invalid hostname" do
      allow(subject).to receive(:value).and_return("wrong-_hostname")
      expect(subject.validate).to eql(false)
    end

    it "considers an empty value as valid returning true" do
      allow(subject).to receive(:value).and_return("")
      expect(subject.validate).to eql(true)
    end

    context "when it is configured to not permit empty values" do
      subject { described_class.new(settings, empty_allowed: false) }

      it "returns false if the input is empty" do
        allow(subject).to receive(:value).and_return("")
        expect(subject.validate).to eql(false)
      end
    end
  end

  describe "#store" do
    it "modifies the given object hostname" do
      allow(subject).to receive(:value).and_return("modified.hostname")
      expect { subject.store }
        .to change { settings.hostname }.from(initial_hostname).to("modified.hostname")
    end
  end
end
