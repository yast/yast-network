#!/usr/bin/env rspec

ENV["Y2DIR"] = File.expand_path("../../src", __FILE__)

require "yast"
require "network/install_inf_convertor"

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

    DEVICE = "enp0s3"
    NETCONFIG = "dhcp"

    before(:each) do
      @install_inf_convertor = Yast::InstallInfConvertor.instance

      Yast::InstallInfConvertor::InstallInf
        .stub(:[]) { "" }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("Netdevice") { DEVICE }
      Yast::InstallInfConvertor::InstallInf
        .stub(:[])
        .with("NetConfig") { NETCONFIG }
    end

    describe "#dev_name" do
      it "returns expected device name" do
        expect(@install_inf_convertor.send(:dev_name)).to eql DEVICE
      end
    end

    describe "#write_ifcfg" do
      it "creates ifcfg file for #{DEVICE}" do
        expect(SCR)
          .to receive(:Write)
          .with(path(".target.string"), /.*-#{DEVICE}/, "") { true }
        expect(@install_inf_convertor.send(:write_ifcfg, "")).to eql true
      end
    end

    describe "#create_ifcfg" do
      it "creates a valid ifcfg for netconfig" do
        expect(ifcfg = @install_inf_convertor.send(:create_ifcfg)).not_to be_empty
        expect(ifcfg).to match /BOOTPROTO='dhcp4'/
        expect(ifcfg).to match /STARTMODE='onboot'/
        expect(ifcfg).to match /NAME='.*'/
      end
    end
  end

end
