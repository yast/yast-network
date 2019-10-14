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

class DummyClass < Yast::Module
  def initialize
    Yast.include self, "network/lan/cmdline.rb"
  end
end

describe "NetworkLanCmdlineInclude" do
  subject { DummyClass.new }

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(
      Y2Network::Config.new(
        source:     :fake,
        interfaces: Y2Network::InterfacesCollection.new([Y2Network::Interface.new("eth0")])
      )
    )
  end

  describe "#validateId" do
    it "reports error and returns false if options missing \"id\"" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({}, [])).to eq false
    end

    it "reports error and returns false if options \"id\" is not number" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({ "id" => "zzz" }, [])).to eq false
    end

    it "reports error and returns false if options \"id\" do not fit config size" do
      expect(Yast::Report).to receive(:Error)

      expect(subject.validateId({ "id" => "5" }, [])).to eq false
    end

    it "returns true otherwise" do
      expect(Yast::Report).to_not receive(:Error)

      expect(subject.validateId({ "id" => "0" }, ["0" => { "id" => "0" }])).to eq true
    end
  end

  describe "#ShowHandler" do
    it "prints to command line" do
      expect(Yast::CommandLine).to receive(:Print)
      expect(Yast::Report).to_not receive(:Error)

      expect(subject.ShowHandler("id" => "0")).to eq true
    end
  end

  describe "#ListHandler" do
    it "prints to command line" do
      expect(Yast::CommandLine).to receive(:Print).at_least(:once)
      expect(Yast::Report).to_not receive(:Error)

      expect(subject.ListHandler({})).to eq true
    end
  end

  describe "#AddHandler" do
    let(:options) { { "name" => "vlan0", "ethdevice" => "eth0", "bootproto" => "dhcp" } }

    before do
      allow(Yast::Report).to receive(:Error)
      allow(Yast::LanItems).to receive(:Commit)
    end

    context "when called without type" do
      let(:no_type_options) { options.reject { |k| k == "ethdevice" } }

      context "and it cannot be infered from the given options" do
        it "reports an error" do
          expect(Yast::Report).to receive(:Error)
          subject.AddHandler(no_type_options)
        end

        it "returns false" do
          expect(subject.AddHandler(no_type_options)).to eq false
        end
      end
    end

    context "when bootproto is given" do
      context "but with an invalid option" do
        it "reports an error" do
          expect(Yast::Report).to receive(:Error)
          subject.AddHandler(options.merge("bootproto" => "wrong"))
        end

        it "returns false" do
          expect(subject.AddHandler(options.merge("bootproto" => "wrong"))).to eq false
        end
      end
    end

    context "when a valid configuration is providen" do
      before do
        allow(subject).to receive(:ListHandler)
      end

      it "commits the new configuration" do
        expect(Yast::LanItems).to receive(:Commit).with(anything)
        subject.AddHandler(options)
      end

      it "lists the final configuration" do
        expect(subject).to receive(:ListHandler)
        subject.AddHandler(options)
      end

      it "returns true" do
        expect(Yast::Report).to_not receive(:Error)
        expect(subject.AddHandler(options)).to eq true
      end
    end
  end

  describe "#EditHandler" do
    let(:options) { { "id" => 0, "ip" => "192.168.0.40" } }

    before do
      allow(subject).to receive(:ShowHandler)
      allow(Yast::Report).to receive(:Error)
      allow(Yast::LanItems).to receive(:Commit)
    end

    context "when a valid configuration is providen" do
      it "commits the configuration changes" do
        expect(Yast::LanItems).to receive(:Commit).with(anything)
        subject.EditHandler(options)
      end

      it "shows the configuration of the edited interface" do
        expect(subject).to receive(:ShowHandler)
        subject.EditHandler(options)
      end

      it "returns true" do
        expect(Yast::Report).to_not receive(:Error)
        expect(subject.EditHandler(options)).to eq true
      end
    end
  end

  describe "#DeleteHandler" do
    let(:options) { { "id" => 0 } }

    before do
      allow(Yast::Report).to receive(:Error)
      allow(Yast::LanItems).to receive(:Commit)
    end

    context "when a valid configuration is providen" do
      it "removes given interface" do
        expect(Yast::LanItems).to receive(:Commit).with(anything)
        subject.EditHandler(options)
      end

      it "returns true" do
        expect(Yast::Report).to_not receive(:Error)
        expect(subject.EditHandler(options)).to eq true
      end
    end
  end
end
