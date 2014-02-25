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
end
