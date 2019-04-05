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

require "y2network/sysconfig_routes_file"

describe Y2Network::SysconfigRoutesFile do
  subject(:file) { described_class.new(path) }

  let(:scr_route) do
    {
      "destination" => destination,
      "device"      => "eth0",
      "gateway"     => gateway,
      "netmask"     => netmask
    }
  end
  let(:destination) { "192.168.122.1" }
  let(:gateway)     { "192.168.122.1" }
  let(:netmask)     { "255.255.255.0" }
  let(:path) { "/etc/sysconfig/network/routes" }

  around do |example|
    create_scr_root = !Dir.exist?(scr_root)
    ::FileUtils.mkdir_p(File.join(scr_root, "/etc/sysconfig/network")) if create_scr_root
    change_scr_root(scr_root, &example)
    ::FileUtils.rm_r(scr_root) if create_scr_root
  end

  describe "#load" do
    let(:scr_root) { File.join(DATA_PATH, "scr_read") }

    it "loads the routes from the given file" do
      file.load
      expect(file.routes.size).to eq(3)
    end

    context "when gateway is missing" do
      let(:gateway) { "-" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "sets the gateway to nil" do
        file.load
        route = file.routes.first
        expect(route.gateway).to be_nil
      end
    end

    context "when there is no netmask" do
      let(:netmask) { "-" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "does not set destination netmask" do
        file.load
        route = file.routes.first
        expect(route.to).to eq(IPAddr.new("192.168.122.1/255.255.255.255"))
      end

      context "but there is a prefix" do
        let(:destination) { "192.168.122.0/24" }

        it "sets the prefix" do
          file.load
          route = file.routes.last
          expect(route.to).to eq(IPAddr.new("192.168.122.0/255.255.255.0"))
        end
      end
    end

    context "when there is no destination" do
      let(:destination) { "default" }

      before(:each) do
        allow(Yast::SCR).to receive(:Read).and_return(nil)
        allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".routes")).and_return([scr_route])
      end

      it "considers the route to be the default one" do
        file.load
        route = file.routes.first
        expect(route.to).to eq(:default)
      end
    end
  end

  describe "#save" do
    let(:scr_root) { File.join(DATA_PATH, "scr_write") }
    let(:path) { "/etc/sysconfig/network/routes" }
    let(:real_path) { File.join(scr_root, path) }

    let(:routes) { [Y2Network::Route.new] }

    it "writes routes to the file" do
      file.routes = routes
      file.save
      content = File.read(real_path)
      expect(content).to eq("default - - - \n")
    end

    context "when there are no routes" do
      let(:routes) { [] }

      it "writes an empty file" do
        file.routes = routes
        file.save
        content = File.read(real_path)
        expect(content).to eq("")
      end
    end

    context "when the file exists" do
      before do
        FileUtils.touch(real_path)
      end

      it "backups the file" do
        file.routes = routes
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.bash"), "/bin/cp #{path} #{path}.YaST2save")
        file.save
      end
    end
  end

  describe "#rm" do
    let(:scr_root) { File.join(DATA_PATH, "scr_write") }

    before do
      allow(Yast::FileUtils).to receive(:Exists).with(file.file_path)
        .and_return(exists?)
    end

    context "when the file exsits" do
      let(:exists?) { true }

      it "removes the file" do
        expect(Yast::SCR).to receive(:Execute)
          .with(Yast::Path.new(".target.remove"), file.file_path)
        file.remove
      end
    end

    context "when the file does not exist" do
      let(:exists?) { false }

      it "removes the file" do
        expect(Yast::SCR).to_not receive(:Execute)
        file.remove
      end
    end
  end
end
