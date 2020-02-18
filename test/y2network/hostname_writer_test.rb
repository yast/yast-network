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
require_relative "../test_helper"
require "y2network/sysconfig/hostname_writer"
require "y2network/hostname"

describe Y2Network::Sysconfig::HostnameWriter do
  subject { Y2Network::Sysconfig::HostnameWriter.new }

  describe ".write" do
    let(:hostname_container) do
      instance_double(
        Y2Network::Hostname,
        static:         hostname,
        dhcp_hostname:  false,
        save_hostname?: true
      )
    end

    let(:old_hostname_container) do
      instance_double(
        Y2Network::Hostname,
        static:         "old#{hostname}",
        dhcp_hostname:  false,
        save_hostname?: true
      )
    end

    before(:each) do
      allow(subject).to receive(:update_sysconfig_dhcp).and_return(nil)
    end

    context "when updating hostname" do
      let(:hostname) { "hostname" }

      it "updates system with the new hostname" do
        expect(Yast::Execute)
          .to receive(:on_target!)
          .with("/usr/bin/hostname", hostname)
        expect(Yast::SCR)
          .to receive(:Write)
          .with(anything, anything, /#{hostname}/)

        subject.write(hostname_container, old_hostname_container)
      end
    end

    context "when deleting hostname" do
      let(:hostname) { "" }

      it "updates system with the new hostname" do
        expect(Yast::Execute)
          .not_to receive(:on_target!)
        expect(Yast::SCR)
          .to receive(:Write)
          .with(anything, anything, /#{hostname}/)

        subject.write(hostname_container, old_hostname_container)
      end
    end

    context "when no change in hostname" do
      let(:hostname) { "hostname" }

      it "do not try to update anything" do
        expect(Yast::Execute)
          .not_to receive(:on_target!)
        expect(Yast::SCR)
          .not_to receive(:Write)
          .with(anything, anything, /#{hostname}/)

        subject.write(hostname_container, hostname_container)
      end
    end
  end
end
