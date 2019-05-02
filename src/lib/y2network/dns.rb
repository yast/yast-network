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
  # DNS configuration (hostname, nameservers, etc.).
  class DNS
    # @return [String] Hostname (local part)
    attr_reader :hostname

    # @return [Array<IPAddr>] List of nameservers
    attr_reader :nameservers

    # @return [Array<String>] List of search domains
    attr_reader :search_domains

    # @return [String] resolv.conf update policy
    attr_reader :resolv_conf_policy

    # @return [Boolean] Whether to take the hostname from DHCP
    attr_reader :dhcp_hostname

    # @todo receive an array instead all these arguments
    #
    # @param opts [Hash] DNS configuration options
    # @option opts [String] :hostname
    # @option opts [Array<String>] :nameservers
    # @option opts [Array<String>] :search_domains
    # @option opts [ResolvConfPolicy] :resolv_conf_policy
    # @option opts [Boolean] :dhcp_hostname
    def initialize(opts = {})
      @hostname = opts[:hostname]
      @nameservers = opts[:nameservers] || []
      @search_domains = opts[:search_domains] || []
      @resolv_conf_policy = opts[:resolv_conf_policy]
      @dhcp_hostname = opts[:dhcp_hostname]
    end

    # Sets a hostname is none is present
    def ensure_hostname!
      return unless @hostname.nil? || @hostname.empty?
      suffix = ("a".."z").to_a.sample(4).join
      @hostname = "linux-#{suffix}"
      nil
    end

    ATTRS = [
      :hostname, :nameservers, :search_domains, :resolv_conf_policy, :dhcp_hostname
    ].freeze

    # Determines whether two set of DNS settings are equal
    #
    # @param other [DNS] DNS settings to compare with
    # @return [Boolean]
    def ==(other)
      ATTRS.all? { |a| public_send(a) == other.public_send(a) }
    end
  end
end
