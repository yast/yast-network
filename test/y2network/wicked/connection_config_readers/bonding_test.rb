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

require_relative "../../../test_helper"
require "y2network/wicked/connection_config_readers/bonding"
require "cfa/interface_file"
require "y2issues"

describe Y2Network::Wicked::ConnectionConfigReaders::Bonding do
  subject(:handler) { described_class.new(file, issues_list) }

  let(:issues_list) { Y2Issues::List.new }
  let(:scr_root) { File.join(DATA_PATH, "scr_read") }

  around do |example|
    change_scr_root(scr_root, &example)
  end

  let(:interface_name) { "bond0" }
  let(:file) do
    CFA::InterfaceFile.find(interface_name).tap(&:load)
  end

  describe "#connection_config" do
    it "returns a bonding connection config object" do
      bonding_conn = handler.connection_config
      expect(bonding_conn.interface).to eq("bond0")
      expect(bonding_conn.slaves).to eq(["eth0", "eth1"])
      expect(bonding_conn.options).to eq("mode=active-backup miimon=100")
    end
  end
end
