#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"

include Yast::I18n
Yast.import "Routing"

describe Yast::Routing do
  before(:all) do
    SYSCTL_IPV4_PATH = path(Yast::RoutingClass::SYSCTL_IPV4_PATH)
    SYSCTL_IPV6_PATH = path(Yast::RoutingClass::SYSCTL_IPV6_PATH)
  end

  # This describes how Routing should behave independently on the way how its
  # internal state was reached
  shared_examples_for "routing setter" do
    before(:each) do
      @value4 = forward_v4 ? "1" : "0"
      @value6 = forward_v6 ? "1" : "0"

      allow(Yast::SCR).to receive(:Execute) { nil }
    end

    context "when Firewall is enabled" do
      before(:each) do
        allow(Yast::SuSEFirewall).to receive(:IsEnabled) { true }
      end

      describe "#WriteIPForwarding" do
        it "Delegates setup to SuSEFirewall2" do
          expect(Yast::SuSEFirewall)
            .to receive(:SetSupportRoute)
            .with(forward_v4)

          expect(Yast::Routing.WriteIPForwarding).to be_equal nil
        end
      end
    end

    context "when Firewall is disabled" do
      before(:each) do
        allow(Yast::SuSEFirewall).to receive(:IsEnabled) { false }
      end

      describe "#WriteIPForwarding" do
        it "Updates IPv4 and IPv6 forwarding in sysctl.conf" do
          allow(Yast::SCR).to receive(:Write) { nil }
          expect(Yast::SCR)
            .to receive(:Write)
            .with(SYSCTL_IPV4_PATH, @value4)
          expect(Yast::SCR)
            .to receive(:Write)
            .with(SYSCTL_IPV6_PATH, @value6)

          expect(Yast::Routing.WriteIPForwarding).to be_equal nil
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
    ].freeze

    CONFIGS_UI.each do |config|
      ipv4 = config[:ip_forward_v4]
      ipv6 = config[:ip_forward_v6]

      context "when user sets IPv4 Forwarding to #{ipv4} and IPv6 to #{ipv6}" do
        before(:each) do
          Yast::Wizard.as_null_object
          Yast::Label.as_null_object
          Yast::Netmask.as_null_object
          Yast::Popup.as_null_object

          Yast.import "UI"
          allow(Yast::UI).to receive(:QueryWidget) { "" }
          expect(Yast::UI)
            .to receive(:QueryWidget)
              .with(Id(:forward_v4), :Value) { ipv4 }
          expect(Yast::UI)
            .to receive(:QueryWidget)
              .with(Id(:forward_v6), :Value) { ipv6 }
          expect(Yast::UI)
            .to receive(:WaitForEvent) { { "ID" => :ok } }

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
    ].freeze

    AY_CONFIGS.each do |config|
      # default value for ip_forward is false
      ipfw = config.key?("ip_forward") ? config["ip_forward"] : false
      # when protocol specific {ipv4,ipv6}_forward is present use it for expectation
      # otherwise use ip_forward as default
      ip4fw = config.key?("ipv4_forward") ? config["ipv4_forward"] : ipfw
      ip6fw = config.key?("ipv6_forward") ? config["ipv6_forward"] : ipfw

      context "when ip_forward is #{ipfw} in AutoYast profile" do
        before(:all) do
          Yast::Routing.Import(config)
        end

        it_should_behave_like "routing setter" do
          let(:forward_v4) { ip4fw }
          let(:forward_v6) { ip6fw }
        end
      end
    end

    describe "#Import" do
      it "Returns true for non nil settings" do
        expect(Yast::Routing.Import({})).to be true
      end

      it "Returns true for nil settings" do
        expect(Yast::Routing.Import(nil)).to be true
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
      ].freeze

      AY_TESTS.each do |ay_test|
        it "Returns hash with proper values" do
          Yast::Routing.Import(ay_test[:input])
          expect(Yast::Routing.Export).to include(*ay_test[:keys])
        end

        it "Overloads generic ip_forward using concrete one" do
          Yast::Routing.Import(ay_test[:input])

          exported = Yast::Routing.Export
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
    ].freeze

    MOCKED_ROUTES = [
      { "destination" => "r1" },
      { "destination" => "r2" }
    ].freeze

    CONFIGS_OS.each do |config|
      ipv4 = config[:ip_forward_v4]
      ipv6 = config[:ip_forward_v6]

      context "when ipv4.ip_forward=#{ipv4} and .ipv6.conf.all.forwarding=#{ipv6}" do
        before(:each) do
          allow(Yast::SCR).to receive(:Read) { nil }
          expect(Yast::SCR)
            .to receive(:Read)
              .with(path(".routes")) { MOCKED_ROUTES.dup }
          expect(Yast::SCR)
            .to receive(:Read)
              .with(SYSCTL_IPV4_PATH) { ipv4 }
          expect(Yast::SCR)
            .to receive(:Read)
              .with(SYSCTL_IPV6_PATH) { ipv6 }

          Yast::Routing.Read
        end

        it_should_behave_like "routing setter" do
          let(:forward_v4) { ipv4 == "1" }
          let(:forward_v6) { ipv6 == "1" }
        end

        describe "#Read" do
          it "loads configuration from system" do
            Yast::NetworkInterfaces.as_null_object

            expect(Yast::Routing.Read).to be true
          end
        end
      end
    end
  end

  describe "#normalize_routes" do
    it "puts prefix length into netmask field when destination is in CIDR format" do
      input_routes = [
        {
          "destination" => "1.1.1.1/24"
        }
      ]

      result = Yast::Routing.normalize_routes(input_routes)

      expect(result.first["destination"]).to eql "1.1.1.1"
      expect(result.first["netmask"]).to eql "/24"
    end

    it "does nothing when netmask is used" do
      input_routes = [
        {
          "destination" => "1.1.1.1",
          "netmask"     => "255.0.0.0"
        }
      ]

      expect(Yast::Routing.normalize_routes(input_routes)).to eql input_routes
    end
  end
end
