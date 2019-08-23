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

require_relative "../../test_helper"
require "cwm/rspec"

require "y2network/widgets/wireless_eap"
require "y2network/interface_config_builder"

describe Y2Network::Widgets::WirelessEap do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"
end

describe Y2Network::Widgets::EapPeap do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"
end

describe Y2Network::Widgets::EapTls do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"
end

describe Y2Network::Widgets::EapTtls do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::CustomWidget"
end

describe Y2Network::Widgets::EapPassword do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::Password"
end

describe Y2Network::Widgets::EapUser do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"
end

describe Y2Network::Widgets::EapAnonymousUser do
  let(:builder) { Y2Network::InterfaceConfigBuilder.for("wlan") }
  subject { described_class.new(builder) }

  include_examples "CWM::InputField"
end
