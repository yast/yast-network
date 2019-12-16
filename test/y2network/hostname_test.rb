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
require "y2network/hostname"

describe Y2Network::Hostname do
  subject(:hostname) do
    Y2Network::Hostname.new(
      static:        static_hostname,
      transient:     transient_hostname,
      installer:     installer_hostname,
      dhcp_hostname: dhcp_hostname
    )
  end

  let(:static_hostname) { nil }
  let(:transient_hostname) { nil }
  let(:installer_hostname) { nil }
  let(:dhcp_hostname) { nil }

  describe "#proposal" do
    let(:static_hostname) { "etc_hostname" }
    let(:transient_hostname) { "net_hostname" }
    let(:installer_hostname) { "install_inf_hostname" }

    context "When used in installer" do
      before(:each) do
        allow(Yast::Stage).to receive(:initial).and_return(true)
      end

      context "with hostname set via linuxrc" do
        it "provides the hostname from linuxrc" do
          expect(hostname.proposal).to eql "install_inf_hostname"
        end
      end

      context "with hostname from network" do
        let(:installer_hostname) { nil }

        it "provides the transient hostname" do
          expect(hostname.proposal).to eql "net_hostname"
        end
      end

      context "with default hostname" do
        let(:installer_hostname) { nil }
        let(:transient_hostname) { nil }

        it "provides hostname set by installer by default" do
          expect(hostname.proposal).to eql "etc_hostname"
        end
      end
    end

    context "When used in running system" do
      before(:each) do
        allow(Yast::Stage).to receive(:initial).and_return(false)
      end

      context "and static hostname is known" do
        it "results in static hostname" do
          expect(hostname.proposal).to eql "etc_hostname"
        end
      end

      context "and static hostname is not known" do
        let(:static_hostname) { nil }

        it "results in transient hostname if there is one" do
          expect(hostname.proposal).to eql "net_hostname"
        end
      end

      context "and no hostname is known" do
        let(:static_hostname) { nil }
        let(:transient_hostname) { nil }

        it "creates a random hostname" do
          expect(hostname.proposal).to match(/linux-[a-z0-9]{4}$/)
        end
      end
    end
  end

  describe "#save_hostname?" do
    context "When used in installer" do
      before(:each) do
        allow(Yast::Stage).to receive(:initial).and_return(true)
      end

      context "without explicitly set hostname" do
        let(:installer_hostname) { nil }

        it "do not propose the hostname to be stored" do
          expect(hostname.save_hostname?).to be false
        end
      end

      context "with explicitly set hostname" do
        let(:installer_hostname) { "install_inf_hostname" }

        it "proposese the hostname to be saved" do
          expect(hostname.save_hostname?).to be true
        end
      end
    end

    context "When used in running system" do
      before(:each) do
        allow(Yast::Stage).to receive(:initial).and_return(false)
      end

      let(:installer_hostname) { nil }

      it "always proposes the hostname to be saved" do
        expect(hostname.save_hostname?).to be true
      end
    end
  end
end
