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
require "y2network/sysconfig/hostname_reader"

describe Y2Network::Sysconfig::HostnameReader do
  subject(:reader) { described_class.new }

  describe "#hostname" do
    let(:install_inf_hostname) { "linuxrc" }
    let(:dhcp_hostname) { "dhcp" }
    let(:system_hostname) { "system" }
    let(:resolver_hostname) { "system.suse.de" }

    before do
      allow(reader).to receive(:hostname_from_install_inf).and_return(install_inf_hostname)
      allow(reader).to receive(:hostname_from_dhcp).and_return(dhcp_hostname)
      allow(reader).to receive(:hostname_from_system).and_return(system_hostname)
      allow(reader).to receive(:hostname_from_resolver).and_return(resolver_hostname)
    end

    context "during installation" do
      let(:install_inf_exists?) { true }

      before do
        allow(Yast::Stage).to receive(:initial).and_return(true)
      end

      it "reads the hostname from /etc/install.conf" do
        expect(reader.hostname_from_install_inf).to eq("linuxrc")
      end

      context "when the /etc/install.inf file does not exists" do
        let(:install_inf_hostname) { nil }

        it "returns nil" do
          expect(reader.hostname_from_install_inf).to be_nil
        end
      end
    end
  end

  describe "#hostname_from_install_inf" do
    let(:hostname) { "foo.bar.com" }

    before do
      allow(Yast::SCR).to receive(:Read).and_return(hostname)
    end

    it "returns the hostname (without the domain)" do
      expect(reader.hostname_from_install_inf).to eq("foo")
    end

    context "when the Hostname is not defined in the install.inf file" do
      let(:hostname) { nil }

      it "returns nil" do
        expect(reader.hostname_from_install_inf).to be_nil
      end
    end

    context "when an IP address is used instead of a hostname" do
      let(:hostname) { "foo1.bar.cz" }

      before do
        allow(Yast::NetHwDetection).to receive(:ResolveIP).and_return(hostname)
      end

      it "returns the associated hostname" do
        expect(reader.hostname_from_install_inf).to eq("foo1")
      end

      context "and it is not resolvable to an IP" do
        let(:hostname) { nil }

        it "returns nil" do
          expect(reader.hostname_from_install_inf).to be_nil
        end
      end
    end
  end

  describe "#hostname_from_system" do
    it "returns the systems' hostname" do
      expect(Yast::Execute).to receive(:on_target!)
        .with("/usr/bin/hostname", stdout: :capture)
        .and_return("foo\n")
      expect(reader.hostname_from_system).to eq("foo")
    end

    context "when the hostname cannot be determined" do
      let(:hostname_content) { "bar\n" }

      before do
        allow(Yast::Execute).to receive(:on_target!)
          .with("/usr/bin/hostname", stdout: :capture)
          .and_raise(Cheetah::ExecutionFailed.new([], "", nil, nil))
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".target.string"), "/etc/hostname")
          .and_return(hostname_content)
      end

      it "returns the name in /etc/hostname" do
        expect(reader.hostname_from_system).to eq("bar")
      end

      context "when the /etc/hostname file is empty" do
        let(:hostname_content) { "\n" }

        it "returns nil" do
          expect(reader.hostname_from_system).to be_nil
        end
      end
    end
  end

  describe "hostname_from_dhcp" do
    before(:each) do
      allow(Yast::NetworkService).to receive(:is_wicked).and_return(true)

      allow(File).to receive(:file?).and_return(false)
    end

    around { |e| change_scr_root(File.join(DATA_PATH, "scr_read"), &e) }

    it "returns name provided as part of dhcp configuration when available on any interface" do
      allow(File)
        .to receive(:file?)
        .with("/var/lib/wicked/lease-eth4-dhcp-ipv4.xml")
        .and_return(true)
      allow(Yast::SCR).to receive(:Execute).and_return("stdout" => "tumbleweed\n")

      expect(reader.hostname_from_dhcp).to eql "tumbleweed"
    end

    it "returns nil when no hostname was obtained from dhcp" do
      expect(reader.hostname_from_dhcp).to be_nil
    end
  end
end
