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
require "y2network/clients/routing"

describe Y2Network::Clients::Routing do
  describe "#main" do
    it "runs the routing cmdline client" do
      allow(subject).to receive(:RoutingGUI)
      expect(subject).to receive(:cmdline_definition)
      subject.main
    end

    context "when calling with no ARGS" do
      it "runs the GUI dialog" do
        expect(subject).to receive(:RoutingGUI)
        subject.main
      end
    end
  end
end
