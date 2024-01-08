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
require_relative "../test_helper"
require "y2network/config_writers/hostname_writer"
require "y2network/hostname"

describe Y2Network::ConfigWriters::HostnameWriter do
  let(:static_hostname) { "test" }
  let(:transient_hostname) { "dhcp_test" }
  let(:installer_hostname) { "test" }
  let(:dhcp_hostname) { :any }

  let(:hostname_container) do
    Y2Network::Hostname.new(static:        static_hostname,
      transient:     transient_hostname,
      dhcp_hostname: dhcp_hostname)
  end

  let(:new_hostname) { hostname_container.dup }

  describe ".write" do
    before(:each) do
      allow(subject).to receive(:update_sysconfig_dhcp).and_return(nil)
    end

    around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

    context "when the static hostname has been modified" do
      let(:hostname) { "new_hostname" }

      it "updates system with the new hostname" do
        new_hostname.static = hostname

        expect(Yast::Execute)
          .to receive(:locally!)
          .with("/usr/bin/hostname", hostname)
        expect(Yast::SCR)
          .to receive(:Write)
          .with(anything, anything, /#{hostname}/)

        subject.write(new_hostname, hostname_container)
      end
    end

    context "when deleting hostname" do
      let(:hostname) { "" }

      it "updates system with the new hostname" do
        new_hostname.static = hostname

        expect(Yast::Execute)
          .not_to receive(:on_target!)
        expect(Yast::SCR)
          .to receive(:Write)
          .with(anything, anything, /#{hostname}/)

        subject.write(new_hostname, hostname_container)
      end
    end

    context "when no change in hostname" do
      let(:hostname) { static_hostname }

      context "and dhcp hostname is set by dhcp" do
        it "does not try to update anything" do
          new_hostname.static = hostname

          expect(Yast::Execute)
            .not_to receive(:on_target!)
          expect(Yast::SCR)
            .not_to receive(:Write)

          subject.write(new_hostname, hostname_container)
        end
      end

      context "and the hostname is not set by dhcp" do
        it "writes the hostname if the dhcp hostname was previously set by dhcp" do
          new_hostname.dhcp_hostname = :none

          expect(Yast::Execute)
            .to receive(:locally!)
            .with("/usr/bin/hostname", hostname)
          expect(Yast::SCR)
            .to receive(:Write)
            .with(anything, anything, /#{hostname}/)

          subject.write(new_hostname, hostname_container)
        end
      end

    end
  end
end
