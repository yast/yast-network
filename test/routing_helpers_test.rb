#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

class RoutingHelpers
  def initialize
    Yast.include self, "network/services/routing.rb"
  end
end

describe "RoutingHelpers" do
  subject(:routing) { RoutingHelpers.new }

  describe "#convert_route_conf" do
    let(:common_route_conf_part) do
      {
        "gateway"     => "1.1.1.1",
        "device"      => "-",
        "extrapara"   => ""
      }
    end
    let(:correct_route_conf) do
      {
        "destination" => "1.1.1.0/24",
        "netmask"     => "-"
      }.merge(common_route_conf_part)
    end
    let(:obsolete_route_conf) do
      {
        "destination" => "1.1.1.0",
        "netmask"     => "255.255.255.0"
      }.merge(common_route_conf_part)
    end

    it "does nothing when route conf uses CIDR notation" do
      expect(routing.convert_route_conf(correct_route_conf)).to eql correct_route_conf
    end

    it "converts obsolete route conf to use CIDR notation" do
      expect(routing.convert_route_conf(obsolete_route_conf)).to eql correct_route_conf
    end
  end
end
