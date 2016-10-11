require "yast"
require "yast2/target_file"

require "cfa/base_model"
require "cfa/matcher"
require "cfa/augeas_parser"

module CFA
  class Hosts < BaseModel
    PARSER = AugeasParser.new("hosts.lns")
    PATH = "/etc/hosts".freeze
    include Yast::Logger

    def initialize(file_handler: nil)
      super(PARSER, PATH, file_handler: file_handler)
    end

    def hosts
      matcher = Matcher.new { |k,v| k =~ /^\d*$/ }
      data.select(matcher).each_with_object({}) do |host, result|
        entry = host[:value]
        result[entry["ipaddr"]] ||= []
        result[entry["ipaddr"]] << single_host_entry(entry)
      end
    end

    def host(ip)
      hosts = data.select(ip_matcher(ip))

      hosts.map do |host|
        single_host_entry(host[:value])
      end
    end

    def delete_host(ip)
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

    # replaces or adds new host entry. If more then one entry with given ip exists
    # then replaces the last instance
    def set_host(ip, canonical, aliases = [])
      entries = data.select(ip_matcher(ip))
      if entries.empty?
        log.info "adding new entry for ip #{ip}"
        entry_line = AugeasTree.new
        entry_line["ipaddr"] = ip
        entry_line["canonical"] = canonical
        aliases_col = entry_line.collection("alias")
        aliases.each do |a|
          aliases_col.add(a)
        end
        data.add(unique_id, entry_line)
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

    # adds new entry, even if it exists
    def add_host(ip, canonical, aliases = [])
      log.info "adding new entry for ip #{ip}"
      entry_line = AugeasTree.new
      entry_line["ipaddr"] = ip
      entry_line["canonical"] = canonical
      aliases_col = entry_line.collection("alias")
      aliases.each do |a|
        aliases_col.add(a)
      end
      data.add(unique_id, entry_line)
    end

    def remove_hostname(hostname)
      entries = data.select(hostname_matcher(hostname))
      entries.each do |entry|
        entry = entry[:value]
        if entry["canonical"] == hostname
          aliases = aliases_for(entry)
          if aliases.empty?
            delete_host(entry["ipaddr"])
          else
            set_host(entry["ipaddr"], aliases.first, aliases[1..-1])
          end
        else
          reduced_aliases = aliases_for(entry)
          reduced_aliases.delete(hostname)
          set_host(entry["ipaddr"], entry["canonical"], reduced_aliases)
        end
      end
    end

  private

    def ip_matcher(ip)
      Matcher.new { |k, v| v["ipaddr"] == ip }
    end

    def hostname_matcher(hostname)
      Matcher.new do |k, v|
        v["canonical"] == hostname || aliases_for(v).include?(hostname)
      end
    end

    def aliases_for(entry)
      entry["alias[]"] ? entry.collection("alias").map{ |a| a } : [entry["alias"]].compact
    end

    def single_host_entry(entry)
      result = [entry["canonical"]]
      result.concat(aliases_for(entry))
      result.join(" ")
    end

    def unique_id
      id = 1
      loop do
        return id.to_s unless data[id.to_s]
        id += 1
      end
    end
  end
end
