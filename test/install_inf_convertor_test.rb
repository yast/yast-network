#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "network/install_inf_convertor"
include Yast # for path shortcut and avoid namespace

describe "InstallInfConvertor" do

  context "in case of no network config in /etc/install.inf" do

    before(:each) do
      @install_inf_convertor = Yast::InstallInfConvertor.instance

      expect(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
        .at_least(:once) { nil }
    end

    describe "#write_dhcp_timeout" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_dhcp_timeout)).to be_false
      end
    end

    describe "#hostname" do
      it "returns empty string" do
        expect(@install_inf_convertor.send(:hostname)).to be_empty
      end
    end

    describe "#write_hostname" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_hostname)).to be_false
      end
    end

    describe "#write_dns" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_dns)).to be_false
      end
    end

    describe "#write_proxy" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_proxy)).to be_false
      end
    end

    describe "#write_nis_domain" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_nis_domain)).to be_false
      end
    end

    describe "#write_connect_wait" do
      it "returns false" do
        expect(@install_inf_convertor.send(:write_connect_wait)).to be_false
      end
    end

    describe "#dev_name" do
      it "returns empty string" do
        expect(@install_inf_convertor.send(:dev_name)).to be_empty
      end

      it "returns empty string even in autoinst mode" do
        Yast.import "Mode"
        Mode.stub(:autoinst) { true }

        expect(@install_inf_convertor.send(:dev_name)).to be_empty
      end
    end

    describe "#write_ifcfg" do
      it "returns false when attempting to write nil content" do
        expect(@install_inf_convertor.send(:write_ifcfg, nil)).to eql false
      end

      it "returns false even when written content is not nil" do
        expect(@install_inf_convertor.send(:write_ifcfg, "STARTMODE='onboot'\n")).to eql false
      end
    end
  end

  context "linuxrc provides dhcp configuration" do

    before(:each) do
      @device = "enp0s3"
      @netconfig = "dhcp"
      @netcardname = "Network card name"

      @install_inf_convertor = Yast::InstallInfConvertor.instance

      Yast::InstallInfConvertor::InstallInf
        .stub(:[]) { "" }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("Netdevice") { @device }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("NetConfig") { @netconfig }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("NetCardName") { @netcardname }
    end

    describe "#dev_name" do
      it "returns expected device name" do
        expect(@install_inf_convertor.send(:dev_name)).to eql @device
      end
    end

    describe "#write_ifcfg" do
      it "creates ifcfg file for #{@device}" do
        expect(SCR)
          .to receive(:Write)
          .with(path(".target.string"), /.*-#{@device}/, "") { true }
        expect(@install_inf_convertor.send(:write_ifcfg, "")).to eql true
      end
    end

    describe "#create_ifcfg" do
      it "creates a valid ifcfg for netconfig" do
        expect(ifcfg = @install_inf_convertor.send(:create_ifcfg)).not_to be_empty
        expect(ifcfg).to match /BOOTPROTO='dhcp4'/
        expect(ifcfg).to match /STARTMODE='onboot'/
        expect(ifcfg).to match /NAME='#{@netcardname}'/
      end
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

      Yast::InstallInfConvertor::InstallInf
        .stub(:[]) { "" }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("Netdevice") { @device }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("NetConfig") { @netconfig }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("IP") { @ip }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("Netmask") { @netmask }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("Nameserver") { @nameserver }
    end

    describe "#create_ifcfg" do
      it "creates a valid ifcfg for netconfig" do
        expect(ifcfg = @install_inf_convertor.send(:create_ifcfg)).not_to be_empty
        expect(ifcfg).to match /BOOTPROTO='static'/
        expect(ifcfg).to match /IPADDR='#{@ip}\/#{Netmask.ToBits(@netmask)}'/
      end
    end

    describe "#write_global_netconfig" do
      it "writes all expected configuration" do
        expect(@install_inf_convertor)
          .to receive(:write_dns)
        expect(@install_inf_convertor.send(:write_global_netconfig))
          .to eql nil
      end
    end

    describe "#write_dns" do
      it "updates global netconfig file" do
        expect(Yast::SCR)
          .to receive(:Write)
          .with(
            path(".sysconfig.network.config"),
            nil
          ) { true }
        expect(Yast::SCR)
          .to receive(:Write)
          .with(
            path(".sysconfig.network.config.NETCONFIG_DNS_STATIC_SERVERS"),
            @nameserver
          ).once { true }
        expect(@install_inf_convertor.send(:write_dns)).to eql true
      end
    end

  end

  describe "#write_proxy" do
    let(:proxy_url) { "http://example.com:3128" }

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

      expect(Yast::InstallInfConvertor.instance.send(:write_proxy)).to be_true
    end

    it "does not write proxy configuration if not defined in install.inf" do
      expect(Yast::InstallInfConvertor::InstallInf).to receive(:[])
        .with("ProxyURL").and_return("")

      expect(Yast::Proxy).to receive(:Read).never
      expect(Yast::Proxy).to receive(:Write).never

      expect(Yast::InstallInfConvertor.instance.send(:write_proxy)).to be_false
    end
  end

  context "running in system z/VM" do
    it "writes hw address into ifcfg for Layer 2 aware qeth devices" do
      HWADDR = "02:AA:BB:CC:DD:FF"

      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
        .with("Layer2")
        .and_return("1")
      allow(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
        .with("Netdevice")
        .and_return("eth1")
      allow(Yast::InstallInfConvertor.instance)
        .to receive(:s390_device_needs_persistent_mac)
        .and_return(true)

      expect(Yast::InstallInfConvertor::InstallInf)
        .to receive(:[])
        .with("HWAddr")
        .and_return(HWADDR)
      expect(Yast::InstallInfConvertor.instance.send(:create_s390_ifcfg, nil).strip!)
        .to eql ("LLADDR='#{HWADDR}'")
    end
  end

end
