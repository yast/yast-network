#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast
include UIShortcuts

# This is needed bcs of Yast.includ(ed) dialog in UI tests
include I18n

Yast.import "Routing"

describe Routing do
  SYSCTL_IPV4_PATH = path(RoutingClass::SYSCTL_IPV4_PATH)
  SYSCTL_IPV6_PATH = path(RoutingClass::SYSCTL_IPV6_PATH)

  # This describes how Routing should behave independently on the way how its
  # internal state was reached
  shared_examples_for "routing setter" do
    before(:each) do
      @value4 = forward_v4 ? "1" : "0"
      @value6 = forward_v6 ? "1" : "0"

      allow(SCR).to receive(:Execute) { nil }
    end

    def fw_independent_write_expects
      expect(SCR)
        .to receive(:Execute)
        .with(
          path(".target.bash"),
          "echo #{@value4} > /proc/sys/net/ipv4/ip_forward"
        )
      expect(SCR)
        .to receive(:Execute)
        .with(
          path(".target.bash"),
          "echo #{@value6} > /proc/sys/net/ipv6/conf/all/forwarding"
        )
    end

    context "when Firewall is enabled" do
      before(:each) do
        allow(SuSEFirewall).to receive(:IsEnabled) { true }
      end

      describe "#WriteIPForwarding" do
        it "Delegates setup to SuSEFirewall2" do
          expect(SuSEFirewall)
            .to receive(:SetSupportRoute)
            .with(forward_v4)

          fw_independent_write_expects

          expect(Routing.WriteIPForwarding).to be_equal nil
        end
      end
    end

    context "when Firewall is disabled" do
      before(:each) do
        allow(SuSEFirewall).to receive(:IsEnabled) { false }
      end

      describe "#WriteIPForwarding" do
        it "Updates IPv4 and IPv6 forwarding in sysctl.conf" do
          allow(SCR).to receive(:Write) { nil }
          expect(SCR)
            .to receive(:Write)
            .with(SYSCTL_IPV4_PATH, @value4)
          expect(SCR)
            .to receive(:Write)
            .with(SYSCTL_IPV6_PATH, @value6)

          fw_independent_write_expects

          expect(Routing.WriteIPForwarding).to be_equal nil
        end
      end
    end
  end

  # Various contexts which mocks different setup sources follows.
  #
  # 1) Test if it behaves correctly when data were obtained from dialog
  #
  context "when set up via dialog" do
    CONFIGS_UI = [
      { ip_forward_v4: false, ip_forward_v6: false },
      { ip_forward_v4: false, ip_forward_v6: true },
      { ip_forward_v4: true, ip_forward_v6: true },
      { ip_forward_v4: true, ip_forward_v6: false }
    ]

    CONFIGS_UI.each do |config|
      ipv4 = config[:ip_forward_v4]
      ipv6 = config[:ip_forward_v6]

      context "when user sets IPv4 Forwarding to #{ipv4} and IPv6 to #{ipv6}" do
        before(:each) do
          Wizard.as_null_object
          Label.as_null_object
          Netmask.as_null_object
          Popup.as_null_object

          Yast.import "UI"
          allow(UI).to receive(:QueryWidget) { "" }
          expect(UI)
            .to receive(:QueryWidget)
              .with(Id(:forward_v4), :Value) { ipv4 }
          expect(UI)
            .to receive(:QueryWidget)
              .with(Id(:forward_v6), :Value) { ipv6 }
          expect(UI)
            .to receive(:WaitForEvent) { { "ID" => :ok }  }

          Yast.include self, "network/services/routing.rb"
          RoutingMainDialog()
        end

        it_should_behave_like "routing setter" do
          let(:forward_v4) { ipv4 }
          let(:forward_v6) { ipv6 }
        end
      end
    end
  end

  #
  # 2) Test if it behaves correctly when data were imported by AutoYast
  #
  context "when working with AutoYast profile" do
    # list of inputs provided by AutoYast
    # keys has to be strings
    AY_CONFIGS = [
      { "ip_forward" => false },
      { "ip_forward" => true },
      { "ipv4_forward" => true },
      { "ipv6_forward" => true },
      { "ip_forward_v4" => false, "ip_forward_v6" => false },
      { "ip_forward_v4" => false, "ip_forward_v6" => true },
      { "ip_forward_v4" => true, "ip_forward_v6" => true },
      { "ip_forward_v4" => true, "ip_forward_v6" => false },
      { "ip_forward" => true, "ip_forward_v4" => false, "ip_forward_v6" => false }
    ]

    AY_CONFIGS.each do |config|
      # default value for ip_forward is false
      ipfw = config.key?("ip_forward") ? config["ip_forward"] : false
      # when protocol specific {ipv4,ipv6}_forward is present use it for expectation
      # otherwise use ip_forward as default
      ip4fw = config.key?("ipv4_forward") ? config["ipv4_forward"] : ipfw
      ip6fw = config.key?("ipv6_forward") ? config["ipv6_forward"] : ipfw

      context "when ip_forward is #{ipfw} in AutoYast profile" do
        before(:all) do
          Routing.Import(config)
        end

        it_should_behave_like "routing setter" do
          let(:forward_v4) { ip4fw }
          let(:forward_v6) { ip6fw }
        end
      end
    end

    describe "#Import" do
      it "Returns true for non nil settings" do
        expect(Routing.Import({})).to be true
      end

      it "Returns true for nil settings" do
        expect(Routing.Import(nil)).to be true
      end
    end

    describe "#Export" do
      # An array of hashes. Each hash should contain keys input: and keys: which
      # describes test this way
      # - input: a hash as provided by AutoYast. Interesting keys are "routes"
      #          and "ip_forward"
      # - keys: array of keys which are expected in obtained hash when above
      #         imported data are exported consequently
      AY_TESTS = [
        {
          input: {},
          keys:  [
            "ipv4_forward",
            "ipv6_forward"
          ]
        },
        {
          input: {
            "ip_forward"   => true,
            "ipv4_forward" => false,
            "ipv6_forward" => false
          },
          keys:  [
            "ipv4_forward",
            "ipv6_forward"
          ]
        },
        {
          input: { "routes" => [{ "1" => "r1" }, { "2" => "r2" }] },
          keys:  [
            "ipv4_forward",
            "ipv6_forward",
            "routes"
          ]
        },
        {
          input: { "ip_forward" => true, "routes" => [{ "1" => "r1" }, { "2" => "r2" }] },
          keys:  [
            "ipv4_forward",
            "ipv6_forward",
            "routes"
          ]
        }
      ]

      AY_TESTS.each do |ay_test|
        it "Returns hash with proper values" do
          Routing.Import(ay_test[:input])
          expect(Routing.Export).to include(*ay_test[:keys])
        end

        it "Overloads generic ip_forward using concrete one" do
          Routing.Import(ay_test[:input])

          exported = Routing.Export
          expect(exported["ipv4_forward"])
            .to eql(ay_test[:input]["ipv4_forward"]) if ay_test[:input].key?("ipv4_forward")
          expect(exported["ipv6_forward"])
            .to eql(ay_test[:input]["ipv6_forward"]) if ay_test[:input].key?("ipv6_forward")
        end
      end
    end
  end

  #
  # 3) Test if it behaves correctly when data were read from system
  #
  context "when working with configuration present in system" do
    CONFIGS_OS = [
      { ip_forward_v4: "0", ip_forward_v6: "0" },
      { ip_forward_v4: "0", ip_forward_v6: "1" },
      { ip_forward_v4: "1", ip_forward_v6: "1" },
      { ip_forward_v4: "1", ip_forward_v6: "0" }
    ]

    MOCKED_ROUTES = [{ "1" => "r1" }, { "2" => "r2" }]

    CONFIGS_OS.each do |config|
      ipv4 = config[:ip_forward_v4]
      ipv6 = config[:ip_forward_v6]

      context "when ipv4.ip_forward=#{ipv4} and .ipv6.conf.all.forwarding=#{ipv6}" do
        before(:each) do
          allow(SCR).to receive(:Read) { nil }
          expect(SCR)
            .to receive(:Read)
              .with(path(".routes")) { MOCKED_ROUTES }
          expect(SCR)
            .to receive(:Read)
              .with(SYSCTL_IPV4_PATH) { ipv4 }
          expect(SCR)
            .to receive(:Read)
              .with(SYSCTL_IPV6_PATH) { ipv6 }

          Routing.Read
        end

        it_should_behave_like "routing setter" do
          let(:forward_v4) { ipv4 == "1" }
          let(:forward_v6) { ipv6 == "1" }
        end

        describe "#Read" do
          it "loads configuration from system" do
            NetworkInterfaces.as_null_object

            expect(Routing.Read).to be true
          end
        end
      end
    end
  end
end
