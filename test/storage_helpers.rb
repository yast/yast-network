# encoding: utf-8

# Copyright (c) [2016-2017] SUSE LLC
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

require "rspec"
require "yast"
require "storage"
require "y2storage"

module StorageHelpers
  def input_file_for(name, suffix: "yml")
    if suffix
      File.join(DATA_PATH, "devicegraphs", "#{name}.#{suffix}")
    else
      File.join(DATA_PATH, "devicegraphs", name)
    end
  end

  def fake_scenario(scenario)
    Y2Storage::StorageManager.fake_from_yaml(input_file_for(scenario))
  end

  def fake_devicegraph
    Y2Storage::StorageManager.instance.y2storage_probed
  end
end
