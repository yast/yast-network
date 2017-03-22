require "yast"
require "yast2/target_file"

require "cfa/base_model"
require "cfa/matcher"
require "cfa/augeas_parser"

module CFA
  # class representings /etc/hosts file model. It provides helper to manipulate
  # with file. It uses CFA framework and Augeas parser.
  # @see http://www.rubydoc.info/github/config-files-api/config_files_api/CFA/BaseModel
  # @see http://www.rubydoc.info/github/config-files-api/config_files_api/CFA/AugeasParser
  class Hosts < BaseModel
    PARSER = AugeasParser.new("hosts.lns")
    PATH = "/etc/hosts".freeze
    include Yast::Logger

    def initialize(file_handler: nil)
      super(PARSER, PATH, file_handler: file_handler)
    end

    # The old format used by {Yast::HostClass}.
    # @return [Hash{String => Array<String>}] keys are IPs,
    #   values are lists of lines in /etc/hosts (not names!)
    #   with whitespace separated hostnames, where the first one is canonical
    #   and the rest are aliases
    #
    #   For example, the file contents
    #
    #       1.2.3.4 www.example.org www
    #       1.2.3.7 log.example.org log
    #       1.2.3.7 sql.example.org sql
    #
    #   is returned as
    #
    #       {
    #         "1.2.3.4" => "www.example.org www"
    #         "1.2.3.7" => [
    #           "log.example.org log",
    #           "sql.example.org sql"
    #         ]
    #       }
    def hosts
      matcher = Matcher.new { |k, _v| k =~ /^\d*$/ }
      data.select(matcher).each_with_object({}) do |host, result|
        entry = host[:value]
        result[entry["ipaddr"]] ||= []
        result[entry["ipaddr"]] << single_host_entry(entry)
      end
    end

    # Returns single entry from hosts for given ip or empty array if not found
    # @see #hosts
    # @return [Array<String>]
    def host(ip)
      hosts = data.select(ip_matcher(ip))

      hosts.map do |host|
        single_host_entry(host[:value])
      end
    end

    # deletes all occurences of given ip in host table
    # @return [void]
    def delete_by_ip(ip)
      entries = data.select(ip_matcher(ip))
      if entries.empty?
        log.info "no entry to delete for ip #{ip}"
        return
      end

      if entries.size > 1
        log.info "delete host with ip '#{ip}' removes more then one entry"
      end

      entries.each do |e|
        log.info "deleting record #{e.inspect}"
        data.delete(e[:key])
      end
    end

    # Replaces or adds a new host entry.
    # If more than one entry with the given ip exists
    # then it replaces the last instance.
    # @param [String] ip
    # @param [String] canonical
    # @param [Array<String>] aliases
    # @return [void]
    def set_entry(ip, canonical, aliases = [])
      entries = data.select(ip_matcher(ip))
      if entries.empty?
        add_entry(ip, canonical, aliases)
        return
      end

      if entries.size > 1
        log.info "more then one entry with ip '#{ip}'. Replacing last one."
      end

      entry = entries.last[:value]
      entry["ipaddr"] = ip
      entry["canonical"] = canonical
      # clear previous aliases
      entry.delete("alias")
      entry.delete("alias[]")
      aliases_col = entry.collection("alias")
      aliases.each do |a|
        aliases_col.add(a)
      end
    end

    # Adds new entry, even if it exists
    # @param [String] ip
    # @param [String] canonical
    # @param [Array<String>] aliases
    # @return [void]
    def add_entry(ip, canonical, aliases = [])
      log.info "adding new entry for ip #{ip}"
      entry_line = AugeasTree.new
      entry_line["ipaddr"] = ip
      entry_line["canonical"] = canonical
      aliases_col = entry_line.collection("alias")
      aliases.each do |a|
        aliases_col.add(a)
      end
      data.add(data.unique_id, entry_line)
    end

    # Removes hostname from all entries in hosts table.
    # If it is the only hostname for a given ip, the ip is removed
    # If it is canonical name, then the first alias becomes the canonical hostname
    # @param [String] hostname
    # @return [void]
    def delete_hostname(hostname)
      entries = data.select(hostname_matcher(hostname))
      entries.each do |pair|
        entry = pair[:value]
        if entry["canonical"] == hostname
          aliases = aliases_for(entry)
          if aliases.empty?
            delete_by_ip(entry["ipaddr"])
          else
            entry["canonical"] = aliases.first
            entry.delete("alias")
            entry.delete("alias[]")
            aliases_col = entry.collection("alias")
            aliases[1..-1].each do |a|
              aliases_col.add(a)
            end
          end
        else
          reduced_aliases = aliases_for(entry)
          reduced_aliases.delete(hostname)
          entry.delete("alias")
          entry.delete("alias[]")
          aliases_col = entry.collection("alias")
          reduced_aliases.each do |a|
            aliases_col.add(a)
          end
        end
      end
    end

    # returns true if hosts include entry with given IP
    def include_ip?(ip)
      entries = data.select(ip_matcher(ip))
      !entries.empty?
    end

  private

    # returns matcher for cfa to find entries with given ip
    def ip_matcher(ip)
      Matcher.new { |_k, v| v["ipaddr"] == ip }
    end

    # returns matcher for cfa to find entries with given hostname
    def hostname_matcher(hostname)
      Matcher.new do |_k, v|
        v["canonical"] == hostname || aliases_for(v).include?(hostname)
      end
    end

    #  returns aliases as array even if there is only one
    def aliases_for(entry)
      entry["alias[]"] ? entry.collection("alias").map { |a| a } : [entry["alias"]].compact
    end

    # generate old format string with first canonical and then aliases
    # all separated by space
    def single_host_entry(entry)
      result = [entry["canonical"]]
      result.concat(aliases_for(entry))
      result.join(" ")
    end
  end
end
