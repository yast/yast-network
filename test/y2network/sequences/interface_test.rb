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

require "y2network/sequences/interface"

Yast.import "Sequencer"

describe Y2Network::Sequences::Interface do
  let(:builder) do
    res = Y2Network::InterfaceConfigBuilder.new
    res.type = "eth"
    res
  end

  describe "#edit" do
    it "calls sequencer" do
      expect(Yast::Sequencer).to receive(:Run)

      subject.edit(builder)
    end
  end

  describe "#init_s390" do
    it "calls sequencer" do
      expect(Yast::Sequencer).to receive(:Run)

      subject.init_s390(builder)
    end
  end

  describe "add" do
    before do
      allow(Yast::Sequencer).to receive(:Run)
      allow(Y2Network::Dialogs::AddInterface).to receive(:run)
    end

    it "calls add interface dialog" do
      expect(Y2Network::Dialogs::AddInterface).to receive(:run)

      subject.add
    end

    it "returns nil if add interface canceled" do
      expect(Yast::Sequencer).to_not receive(:Run)
      allow(Y2Network::Dialogs::AddInterface).to receive(:run).and_return(nil)

      expect(subject.add).to eq nil
    end

    it "calls edit sequencer if add interface selected" do
      expect(Yast::Sequencer).to receive(:Run)
      allow(Y2Network::Dialogs::AddInterface).to receive(:run).and_return(builder)

      subject.add
    end

    it "calls add again if edit sequencer goes back" do
      expect(Yast::Sequencer).to receive(:Run).and_return(:back, :next)
      expect(Y2Network::Dialogs::AddInterface).to receive(:run).twice.and_return(builder)

      subject.add
    end
  end
end
