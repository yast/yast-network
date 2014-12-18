#!/usr/bin/env rspec

require_relative "test_helper"
require "yast"

module Yast
  import "SuSEFirewall4Network"
  import "WFM"

  describe "Lan autoinstallation" do

    context "Importing data" do

      it "keep_install_network set. Firewall setting will not be reset" do
        expect(SuSEFirewall4Network).to_not receive(:Read)
        Yast::WFM.CallFunction("lan_auto", ["Import", 
          {"keep_install_network"=>true, "start_immediately"=>:true}])
      end
    end
  end
end
