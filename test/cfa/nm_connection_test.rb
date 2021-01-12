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

require_relative "../test_helper"
require "cfa/nm_connection"
require "cfa/memory_file"

describe CFA::NmConnection do
  def file_path(filename)
    File.join(SCRStub::DATA_PATH, filename)
  end

  subject { described_class.new(conn_file) }
  let(:conn_file) { file_path("some_wifi.nmconnection") }

  describe "#connection" do
    before { subject.load }

    it "returns the [connection] section" do
      expect(subject.connection["id"]).to eq("MyWifi")
    end

    context "when the connection section is missing" do
      let(:conn_file) { file_path("empty.nmconnection") }

      it "returns an empty connection section" do
        expect(subject.connection["id"]).to be_nil
      end
    end
  end
end
