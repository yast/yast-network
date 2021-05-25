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
require "y2network/wicked/hostname_reader"
require "y2network/equatable"

Yast.import "Stage"

module Y2Network
  # Hostname configuration
  class Hostname
    include Equatable

    # @return [String] hostname as got from /etc/hostname
    attr_accessor :static

    # @return [String] dynamically defined hostname (e.g. from DHCP), defaults to static
    attr_accessor :transient

    # @return [String, nil] hostname as read from linuxrc (if set) or explicitly set
    #                       in installer, nil otherwise
    attr_accessor :installer

    # @return [String,Symbol] Whether to take the hostname from DHCP.
    #   It can be an interface name (String), :any for any interface or :none from no taking
    #   the hostname from DHCP.
    attr_accessor :dhcp_hostname

    # @todo receive an array instead all these arguments
    #
    # @param opts [Hash] hostname configuration options
    # @option opts [String] :static
    # @option opts [String] :transient
    # @option opts [String] :installer
    # @option opts [String, Symbol] :dhcp_hostname
    def initialize(opts = {})
      @static = opts[:static]
      @transient = opts[:transient] || @static
      @installer = opts[:installer]
      @dhcp_hostname = opts[:dhcp_hostname]
    end

    # @return [String] Hostname presented to user in different modes.
    # NOTE: we have different workflows where to query for the system hostname in running
    # system or installation. This presents result of the particular workflow (depending
    # when the object was created)
    def proposal
      if Yast::Stage.initial
        hostname_for_installer
      else
        hostname_for_running_system
      end
    end

    alias_method :hostname, :proposal

    eql_attr :dhcp_hostname, :static, :transient, :installer

    # Reads the static hostname from /etc/hostname
    #
    # @return [String, nil]
    def current_static
      name = Yast::SCR.Read(Yast::Path.new(".target.string"), "/etc/hostname").to_s.strip
      name.empty? ? nil : name
    end

    # Returns whether the static hostname is different than the current one
    #
    # #@return [Boolean]
    def static_modified?
      @static != current_static.to_s
    end

  private

    # @return [Array<String>] Valid chars to be used in the random part of a hostname
    HOSTNAME_CHARS = (("a".."z").to_a + ("0".."9").to_a).freeze
    private_constant :HOSTNAME_CHARS

    # Returns a random hostname
    #
    # The idea is to use a name like this as fallback.
    #
    # @return [String]
    def random_hostname
      suffix = HOSTNAME_CHARS.sample(4).join
      "linux-#{suffix}"
    end

    # Runs workflow for querying hostname in the installer
    #
    # @return [String] Hostname
    def hostname_for_installer
      # the hostname was either explicitly set by the user, obtained from dhcp or implicitly
      # preconfigured by the linuxrc (install). Do not generate random one as we did in the past.
      # See FATE#319639 for details.
      @installer || @transient || @static
    end

    # Runs workflow for querying hostname in the installed system
    #
    # @return [String] Hostname
    def hostname_for_running_system
      @static || @transient || random_hostname
    end
  end
end
