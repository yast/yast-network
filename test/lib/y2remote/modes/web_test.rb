#!/usr/bin/env rspec

# ------------------------------------------------------------------------------
# Copyright (c) 2019 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require_relative "../../../test_helper.rb"
require "y2remote/remote"

describe Y2Remote::Modes::Web do
  subject { Y2Remote::Modes::Web.instance }

  it "requires xorg-x11-Xvnc-novnc" do
    expect(subject.required_packages).to include("xorg-x11-Xvnc-novnc")
  end

  context "when system is SLE" do
    before do
      allow(Yast::OSRelease).to receive(:ReleaseInformation).and_return("SUSE Linux Enterprise")
    end

    it "requires python-PyJWT" do
      expect(subject.required_packages).to include("python-PyJWT")
    end

    it "requires python-cryptography" do
      expect(subject.required_packages).to include("python-cryptography")
    end

    it "does not require python-jwcrypto" do
      expect(subject.required_packages).to_not include("python-jwcrypto")
    end
  end

  context "when system is openSUSE" do
    before do
      allow(Yast::OSRelease).to receive(:ReleaseInformation).and_return("openSUSE TW")
    end

    it "requires python-jwcrypto" do
      expect(subject.required_packages).to include("python-jwcrypto")
    end

    it "does not require python-PyJWT" do
      expect(subject.required_packages).to_not include("python-PyJWT")
    end

    it "does not require python-cryptography" do
      expect(subject.required_packages).to_not include("python-cryptography")
    end
  end
end
