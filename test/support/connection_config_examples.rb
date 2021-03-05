# Copyright (c) [2021] SUSE LLC
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

RSpec.shared_examples "connection configuration" do
  describe "#propose" do
    context "startmode" do
      let(:normal?) { true }
      let(:root_in_network?) { false }

      let(:storage_manager) do
        instance_double(Y2Storage::StorageManager, staging: devicegraph)
      end

      let(:devicegraph) { instance_double(Y2Storage::Devicegraph) }

      before do
        allow(Yast::Mode).to receive(:normal).and_return(normal?)
        allow(Y2Storage::StorageManager).to receive(:instance)
          .and_return(storage_manager)
        allow(devicegraph).to receive(:filesystem_in_network?).with("/")
          .and_return(root_in_network?)
      end

      context "when root filesystem is on a network device" do
        let(:root_in_network?) { true }

        it "is set to 'nfsroot'" do
          subject.propose
          expect(subject.startmode.to_s).to eq("nfsroot")
        end
      end

      context "when running on installation" do
        let(:normal?) { false }

        it "does not check whether the root filesystem is on a network device" do
          expect(storage_manager).to_not receive(:staging)
          subject.propose
        end
      end
    end
  end
end
