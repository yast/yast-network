#! /usr/bin/env rspec

require_relative "test_helper"

require "yast"

class DnsServiceClass
  include Yast::UIShortcuts
  include Yast::I18n

  def initialize
    Yast.include self, "network/services/dns.rb"
  end
end

describe "#ValidateDomain" do
  subject(:dns) { DnsServiceClass.new }

  it "accepts empty domain" do
    Yast.import "UI"

    allow(Yast::UI)
      .to receive(:QueryWidget)
      .with(Id("DHCP_HOSTNAME"), :Value)
      .and_return(false)
    allow(Yast::UI)
      .to receive(:QueryWidget)
      .and_return("")
    expect(dns.ValidateDomain("DOMAIN", nil))
      .to be true
  end
end
