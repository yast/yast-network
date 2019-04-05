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
require "y2network/config_writer/sysconfig_routes_writer"

describe Y2Network::ConfigWriter::SysconfigRoutesWriter do
  subject(:writer) { described_class.new }

  describe "#write" do
    let(:eth0) { Y2Network::Interface.new("eth0") }
    let(:route) do
      Y2Network::Route.new(
        to:        IPAddr.new("10.0.0.2/8"),
        interface: eth0,
        gateway:   IPAddr.new("192.168.122.1")
      )
    end
    let(:scr) { class_double(Yast::SCR).as_stubbed_const(:transfer_nested_constants => true) }

    context "When modifying global default routes file" do
      before(:each) do
        expect(scr)
          .to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), /YaST2save/)
      end

      context "When routes are defined" do
        it "Writes routes" do
          allow(Yast::FileUtils).to receive(:Exists).and_return(true)

          expect(scr)
            .to receive(:Write)
            .with(instance_of(Yast::Path), [{
              "destination" => "10.0.0.0/8",
              "netmask" =>     "-",
              "gateway" =>     "192.168.122.1",
              "device" =>      "eth0"
            }])

          writer.write([route])
        end
      end

      context "When no routes are defined" do
        it "Clears routes file" do
          allow(Yast::FileUtils).to receive(:Exists).and_return(true)

          expect(scr)
            .to receive(:Write)
            .with(instance_of(Yast::Path), "/etc/sysconfig/network/routes", "")

          writer.write([])
        end
      end
    end
  end
end
