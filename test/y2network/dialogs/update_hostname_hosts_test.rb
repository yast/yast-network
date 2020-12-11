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

require "y2network/dialogs/update_hostname_hosts"

describe Y2Network::Dialogs::UpdateHostnameHosts do
  subject { described_class.new(eth0_conn) }

  include_examples "CWM::Dialog"

  let(:ip) do
    Y2Network::ConnectionConfig::IPConfig.new(Y2Network::IPAddress.new("192.168.122.10", 24))
  end

  let(:eth0_conn) do
    Y2Network::ConnectionConfig::Ethernet.new.tap do |conn|
      conn.interface = "eth0"
      conn.name = "eth0"
      conn.bootproto = :static
      conn.ip = ip
      conn.hostnames = ["yast.suse.com", "yast"]
    end
  end
end
