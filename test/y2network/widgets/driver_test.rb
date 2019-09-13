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

require "y2network/widgets/driver"

describe Y2Network::Widgets::Driver do
  subject(:widget) { described_class.new(builder) }

  let(:builder) do
    Y2Network::InterfaceConfigBuilder.for("eth")
  end
  let(:virtio_net) { Y2Network::Driver.new("virtio_net", "csum=1") }

  before do
    allow(builder).to receive(:drivers).and_return([virtio_net])
    allow(builder).to receive(:driver).and_return(virtio_net)
  end

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    it "contains a kernel module widget" do
      expect(Y2Network::Widgets::KernelModule).to receive(:new)
        .with(["virtio_net"], "virtio_net")
      widget.contents
    end

    it "contains a kernel options widget" do
      expect(Y2Network::Widgets::KernelOptions).to receive(:new)
        .with("csum=1")
      widget.contents
    end
  end

  describe "#handle"
end
