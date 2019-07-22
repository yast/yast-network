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
module Y2Network
  module ConnectionConfig
    class IPConfig
      # @return [IPAddress] IP address
      attr_accessor :address
      # @return [Symbol] Address scope (:global, :site, :link or :host)
      attr_accessor :scope
      # @return [String,nil] Address label
      attr_accessor :label
      # @return [IPAddress,nil] Remote IP address of a point to point connection
      attr_accessor :remote_address
      # @return [IPAddress,nil] Broadcast address
      attr_accessor :broadcast
      # @return [Symbol,String] ID (needed for sysconfig backend in order to write suffixes in
      attr_accessor :id

      # Constructor
      #
      # @param address [IPAddress]
      # @param id      [Symbol,String] ID (needed for sysconfig backend in order to write suffixes in
      #   ifcfg-* files)
      # @param scope   [Symbol]
      # @param label   [String,nil]
      # @param remote_address [IPaddress,nil]
      # @param broadcast [IPaddress,nil]
      def initialize(address:, id: nil, scope: nil, label: nil, remote_address: nil, broadcast: nil)
        @address = address
        @id = id || :default
        @scope = scope || :global
        @label = label
        @remote_address = remote_address
        @broadcast = broadcast
      end
    end
  end
end
