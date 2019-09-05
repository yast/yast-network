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
require "y2network/hostname_reader"

describe Y2Network::HostnameReader do
  subject(:reader) { described_class.new }

  describe "#hostname" do
    let(:install_inf_hostname) { "linuxrc" }
    let(:system_hostname) { "system" }

    before do
      allow(reader).to receive(:hostname_from_install_inf).and_return(install_inf_hostname)
      allow(reader).to receive(:hostname_from_system).and_return(system_hostname)
      allow(reader).to receive(:random_hostname).and_return("linux-abcd")
    end

    it "returns the system's hostname" do
      expect(reader.hostname).to eq("system")
    end

    context "when the hostname cannot be determined" do
      let(:system_hostname) { nil }

      it "returns a random one" do
        expect(reader.hostname).to eq("linux-abcd")
      end
    end

    context "during installation" do
      let(:install_inf_exists?) { true }

      before do
        allow(Yast::Mode).to receive(:installation).and_return(true)
        allow(Yast::FileUtils).to receive(:Exists).with("/etc/install.inf")
          .and_return(install_inf_exists?)
      end

      it "reads the hostname from /etc/install.conf" do
        expect(reader.hostname).to eq("linuxrc")
      end

      context "when the /etc/install.inf file does not exists" do
        let(:install_inf_exists?) { false }

        it "reads the hostname from the system" do
          expect(reader.hostname).to eq("system")
        end
      end

      context "when the hostname cannot be determined" do
        let(:install_inf_hostname) { nil }
        let(:system_hostname) { nil }

        it "returns a random one" do
          expect(reader.hostname).to eq("linux-abcd")
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
    let(:executor) do
      double("Yast::Execute", on_target!: "foo")
    end

    before do
      allow(Yast::Execute).to receive(:stdout).and_return(executor)
    end

    it "returns the systems' hostname" do
      expect(executor).to receive(:on_target!).with("/bin/hostname", "--fqdn").and_return("foo")
      expect(reader.hostname_from_system).to eq("foo")
    end

    context "when the hostname cannot be determined" do
      before do
        allow(executor).to receive(:on_target!).with("/bin/hostname", "--fqdn")
          .and_raise(Cheetah::ExecutionFailed.new([], "", nil, nil))
      end

      it "returns nil" do
        expect(reader.hostname_from_system).to be_nil
      end
    end
  end

  describe "#random_hostname" do
    it "returns a random name" do
      expect(reader.random_hostname).to match(/linux-\w{4}/)
    end
  end
end
