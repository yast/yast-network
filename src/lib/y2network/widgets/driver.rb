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

require "yast"
require "cwm"
require "y2network/widgets/kernel_module"
require "y2network/widgets/kernel_options"

module Y2Network
  module Widgets
    # Widget to select the driver and to specify its options
    class Driver < CWM::CustomWidget
      include Yast::Logger

      def initialize(builder)
        textdomain "network"
        @builder = builder
        self.handle_all_events = true
      end

      def contents
        Frame(
          _("&Kernel Module"),
          HBox(
            HSpacing(0.5),
            VBox(
              VSpacing(0.4),
              HBox(
                kernel_module_widget,
                HSpacing(0.5),
                kernel_options_widget
              ),
              VSpacing(0.4)
            ),
            HSpacing(0.5)
          )
        )
      end

      def handle(event)
        return unless event["ID"] == "kernel_module" && event["EventReason"] == "ValueChanged"
        return nil if @old_kernel_module == kernel_module_widget.value

        new_driver = @builder.drivers.find { |d| d.name == kernel_module_widget.value }
        kernel_options_widget.value = new_driver.params if new_driver
        @old_kernel_module = kernel_module_widget.value

        nil
      end

      def store
        @builder.driver = Y2Network::Driver.new(kernel_module_widget.value, kernel_options_widget.value)
      end

    private

      def kernel_module_widget
        return @kernel_module_widget if @kernel_module_widget
        drivers_names = @builder.drivers.map(&:name)
        selected_driver = @builder.driver.name if @builder.driver
        @kernel_module_widget = KernelModule.new(drivers_names, selected_driver)
      end

      def kernel_options_widget
        return @kernel_options_widget if @kernel_options_widget
        options = @builder.driver ? @builder.driver.params : ""
        @kernel_options_widget ||= KernelOptions.new(options)
      end
    end
  end
end
