#!/usr/bin/env rspec

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

require_relative "test_helper"

require "yast"
require "network/install_inf_convertor"

stub_module "Proxy"

describe "InstallInfConvertor" do
  context "in case of no network config in /etc/install.inf" do
    before(:each) do
      @install_inf_convertor = Yast::InstallInfConvertor.instance

      expect(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .at_least(:once) { nil }
    end

    describe "#hostname" do
      it "returns empty string" do
        expect(@install_inf_convertor.send(:hostname)).to be_empty
      end
    end

    describe "#write_hostname" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_hostname)).to be false
      end
    end

    describe "#write_proxy" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_proxy)).to be false
      end
    end

  end

  context "linuxrc provides dhcp configuration" do
    before(:each) do
      @device = "enp0s3"
      @netconfig = "dhcp"
      @netcardname = "Network card name"

      @install_inf_convertor = Yast::InstallInfConvertor.instance

      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[]) { "" }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("Netdevice") { @device }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("NetConfig") { @netconfig }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("NetCardName") { @netcardname }
    end

  end

  context "linuxrc provides static configuration" do
    before(:each) do
      Yast.import "Netmask"

      @device = "enp0s3"
      @ip = "10.121.157.133"
      @netmask = "255.255.240.0"
      @netconfig = "static"
      @nameserver = "10.120.0.1"

      @install_inf_convertor = Yast::InstallInfConvertor.instance

      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[]) { "" }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("Netdevice") { @device }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("NetConfig") { @netconfig }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("IP") { @ip }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("Netmask") { @netmask }
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
          .with("Nameserver") { @nameserver }
    end

    describe "#write_global_netconfig" do
      it "writes all expected configuration" do
        expect(@install_inf_convertor.send(:write_global_netconfig))
          .to eql nil
      end
    end
  end

  describe "#write_proxy" do
    let(:proxy_url) { "http://example.com:3128" }
    let(:auth_proxy_url) { "http://user:passwd@example.com:3128" }

    it "writes proxy configuration if defined in install.inf" do
      expect(Yast::InstallInfConvertor::InstallInf).to receive(:[])
        .with("ProxyURL").and_return(proxy_url)

      expect(Yast::Proxy).to receive(:Read).and_return(true)
      expect(Yast::Proxy).to receive(:Export).and_return(
        "enabled"        => false,
        "http_proxy"     => "",
        "https_proxy"    => "",
        "ftp_proxy"      => "",
        "no_proxy"       => "localhost, 127.0.0.1",
        "proxy_user"     => "",
        "proxy_password" => ""
      )
      expect(Yast::Proxy).to receive(:Import) do |config|
        # proxy is enabled and the URL is set
        expect(config).to include("enabled" => true, "http_proxy" => proxy_url)
      end
      expect(Yast::Proxy).to receive(:Write).and_return(true)

      expect(Yast::InstallInfConvertor.instance.send(:write_proxy)).to be true
    end

    it "writes proxy credentials separately" do
      expect(Yast::InstallInfConvertor::InstallInf).to receive(:[])
        .with("ProxyURL").and_return(auth_proxy_url)

      expect(Yast::Proxy).to receive(:Read).and_return(true)
      expect(Yast::Proxy).to receive(:Export).and_return(
        "enabled"        => false,
        "http_proxy"     => "",
        "https_proxy"    => "",
        "ftp_proxy"      => "",
        "no_proxy"       => "localhost, 127.0.0.1",
        "proxy_user"     => "",
        "proxy_password" => ""
      )
      expect(Yast::Proxy).to receive(:Import) do |config|
        # proxy is enabled and the URL without credentials is set
        expect(config).to include("enabled" => true, "http_proxy" => proxy_url,
          "proxy_user" => "user", "proxy_password" => "passwd")
      end
      expect(Yast::Proxy).to receive(:Write).and_return(true)

      expect(Yast::InstallInfConvertor.instance.send(:write_proxy)).to be true
    end

    it "does not write proxy configuration if not defined in install.inf" do
      expect(Yast::InstallInfConvertor::InstallInf).to receive(:[])
        .with("ProxyURL").and_return("")

      expect(Yast::Proxy).to receive(:Read).never
      expect(Yast::Proxy).to receive(:Write).never

      expect(Yast::InstallInfConvertor.instance.send(:write_proxy)).to be false
    end
  end
end
