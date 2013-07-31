# encoding: utf-8

#***************************************************************************
#
# Copyright (c) 2012 Novell, Inc.
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail,
# you may find current contact information at www.novell.com
#
#**************************************************************************
# File:	modules/Provider.ycp
# Package:	Network configuration
# Summary:	Provider data
# Authors:	Dan Vesely <dan@suse.cz>
#		Petr Blahos <pblahos@suse.cz>
#		Michal Svec <msvec@suse.cz>
#
#
# Used by Modem, ISDN, DSL.
# The provider data is grouped by country. There are predefined ones
# (providers.rpm) and custom ones (/etc/sysconfig/network/providers,
# represented here as country = "_custom")
require "yast"

module Yast
  class ProviderClass < Module
    def main
      textdomain "network"

      Yast.import "HTML"
      Yast.import "Map"
      Yast.import "String"
      Yast.import "Summary"

      #------------------
      # GLOBAL VARIABLES

      # Current provider name
      @Name = ""

      # Current provider
      # structure depends on Type. See providers.rpm
      @Current = {}

      # Current provider type
      @Type = "modem"

      # Last selected country
      @LastCountry = nil

      #-----------------
      # LOCAL VARIABLES

      # Supported provider types
      @Supported = ["modem", "isdn", "dsl"]

      # Custom providers
      # (system ones are too many and thus read on demand)
      @Providers = {}

      # Custom providers (initial copy)
      @OriginalProviders = {}

      # Countries list
      @Countries = []

      # Deleted providers
      @Deleted = []

      # Pending operation (nil = none)
      @operation = nil

      # True if providers are already read
      @initialized = false

      # Country
      @country = nil
    end

    # Were the providers changed?
    # @return true if modified
    def Modified(type)
      return false if !CheckType(type)
      _OriginalProvs = Filter(@OriginalProviders, type)
      _Provs = Filter(@Providers, type)
      diff = _Provs != _OriginalProvs
      diff
    end

    # Read providers data (custom only) and country mappings
    # @return true if success
    def Read
      ret = true
      return true if @initialized

      # Read custom providers
      @Providers = {}
      dir = SCR.Dir(path(".sysconfig.network.providers.s"))

      # Filter away backups (files with ~)
      dir = Builtins.filter(dir) { |file| !Builtins.regexpmatch(file, "[~]") }

      # Fill the Providers map
      Builtins.foreach(dir) do |name|
        prov = Builtins.add(path(".sysconfig.network.providers.v"), name)
        p = Builtins.listmap(SCR.Dir(prov)) do |i|
          ii = {}
          # TODO: quoting should be improved everywhere
          Ops.set(
            ii,
            i,
            String.UnQuote(Convert.to_string(SCR.Read(Builtins.add(prov, i))))
          )
          deep_copy(ii)
        end
        Ops.set(@Providers, name, p)
      end
      @OriginalProviders = deep_copy(@Providers)

      # Read countries
      country_names = Convert.to_map(
        Builtins.eval(SCR.Read(path(".target.yast2"), "country.ycp"))
      )
      if country_names == nil
        #Report:Error(_("Country database not found"));
        Builtins.y2error("Country database not found")
        country_names = {}
        ret = false
      end
      textdomain "country"
      country_names = Builtins.eval(country_names)
      textdomain "network"

      # Country heuristics
      @country = GetCountry()
      @LastCountry = @country
      Builtins.y2debug("LastCountry=%1", @LastCountry)

      # Initialize the countries selection box
      @Countries = []
      index = -1
      @Countries = SCR.Dir(path(".providers.s"))
      @Countries = [] if @Countries == nil
      Builtins.y2debug("Countries=%1", @Countries)
      @LastCountry = "CZ" if !Builtins.contains(@Countries, @LastCountry)
      @Countries = Builtins.maplist(
        Convert.convert(@Countries, :from => "list", :to => "list <string>")
      ) do |i|
        index = Ops.add(index, 1)
        Item(Id(i), Ops.get_string(country_names, i, i), i == @LastCountry)
      end
      Builtins.y2debug("Countries=%1", @Countries)

      # Read system providers
      # Slow -- better read them upon request (SelectSystem)
      # map P = $[];
      # P = listmap(string cs, SCR::Dir(.providers.s), {
      # 	path pp = add(.providers.s, cs);
      # 	// y2debug("--- (%1), %2 ---", pp, SCR::Dir(pp));
      # 	return [ cs, listmap(string c, SCR::Dir(pp), {
      # 	    pp = add(add(.providers.v, cs), c);
      # 	    // y2debug("--- %1 ---", SCR::Dir(pp));
      # 	    return [ c,
      # 	    listmap(string vs, SCR::Dir(pp), {
      # 		// y2debug("%1=%2", vs, SCR::Read(add(pp, vs)));
      # 		return [ vs, SCR::Read(add(pp, vs)) ];
      # 	    }) ];
      # 	}) ];
      # });

      @initialized = true
      ret
    end

    # This is a single point of dependence on the Language module of yast2-country-data
    def GetCountry
      Yast.import "Language"
      Language.GetLanguageCountry
    end
    def Filter(providers, type)
      providers = deep_copy(providers)
      if providers == nil || type == nil || type == "" || type == "all"
        return deep_copy(providers)
      end

      Builtins.filter(providers) do |k, v|
        Builtins.y2debug(
          "%1 %2",
          Ops.get_string(v, "PROVIDER", ""),
          Ops.get_string(v, Ops.add(Builtins.toupper(type), "SUPPORTED"), "no")
        )
        Ops.get_string(v, Ops.add(Builtins.toupper(type), "SUPPORTED"), "no") == "yes"
      end
    end


    def FilterNOT(providers, type)
      providers = deep_copy(providers)
      if providers == nil || type == nil || type == "" || type == "all"
        return {}
      end

      Builtins.filter(providers) do |k, v|
        Builtins.y2debug(
          "%1 %2",
          Ops.get_string(v, "PROVIDER", ""),
          Ops.get_string(v, Ops.add(Builtins.toupper(type), "SUPPORTED"), "no")
        )
        Ops.get_string(v, Ops.add(Builtins.toupper(type), "SUPPORTED"), "no") == "no"
      end
    end
    def CheckType(type)
      Builtins.y2debug(2, "type=%1", type)
      if type != "all" && !Builtins.contains(@Supported, type)
        Builtins.y2error(2, "Unsupported provider type: %1", type)
        return false
      end
      true
    end

    # Write custom providers data
    # @param [String] type providers the module is working with ("all"|"modem"|"isdn"|"dsl")
    # @return true if sucess
    def Write(type)
      Builtins.y2milestone("Writing configuration")

      ret = true
      return false if !CheckType(type)

      _OriginalProvs = Convert.convert(
        Filter(@OriginalProviders, type),
        :from => "map",
        :to   => "map <string, map>"
      )
      _Provs = Convert.convert(
        Filter(@Providers, type),
        :from => "map",
        :to   => "map <string, map <string, string>>"
      )
      Builtins.y2debug("OriginalProvs=%1", _OriginalProvs)
      Builtins.y2debug("Provs=%1", _Provs)

      # Check for changes
      if _Provs == _OriginalProvs
        Builtins.y2milestone(
          "No changes to %1 providers -> nothing to write",
          type
        )
        return true
      end

      # Remove deleted custom providers
      Builtins.foreach(@Deleted) do |provider|
        next if !Builtins.haskey(_OriginalProvs, provider)
        p = Builtins.add(path(".sysconfig.network.providers.section"), provider)
        Builtins.y2debug("deleting: %1", p)
        SCR.Write(p, nil)
      end
      @Deleted = Builtins.filter(@Deleted) do |prov|
        Builtins.haskey(_OriginalProvs, prov)
      end
      Builtins.y2debug("Deleted=%1", @Deleted)

      # Write custom providers
      Builtins.foreach(_Provs) do |name, provider|
        name = Builtins.filterchars(
          name,
          "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."
        )
        base = Builtins.add(path(".sysconfig.network.providers.v"), name)
        # Ensure all neccesary items are present
        if !Builtins.haskey(provider, "MODEMSUPPORTED")
          Ops.set(provider, "MODEMSUPPORTED", "yes")
        end
        if !Builtins.haskey(provider, "ISDNSUPPORTED")
          Ops.set(provider, "ISDNSUPPORTED", "no")
        end
        if !Builtins.haskey(provider, "DSLSUPPORTED")
          Ops.set(provider, "DSLSUPPORTED", "no")
        end
        # Write all values
        Builtins.foreach(provider) do |k, v|
          # Adjust some values
          if k == "ASKPASSWORD" || k == "STUPIDMODE" || k == "COMPUSERVE" ||
              k == "ISDNSUPPORTED" ||
              k == "DSLSUPPORTED" ||
              k == "MODEMSUPPORTED"
            if v == "0"
              v = "no"
            elsif v == "1"
              v = "yes"
            elsif v != "no" && v != "yes"
              v = Builtins.search(v, "no") != nil ? "no" : "yes"
            end
          end
          # Do the write
          SCR.Write(Builtins.add(base, k), String.Quote(v))
        end
      end

      # Flush
      SCR.Write(path(".sysconfig.network.providers"), nil)

      ret
    end

    # Import data
    # @param [Hash] providers providers to be imported
    # @return true on success
    def Import(type, providers)
      providers = deep_copy(providers)
      return {} if !CheckType(type)
      _Provs = FilterNOT(@Providers, type)
      Builtins.y2debug("Provs=%1", _Provs)

      @Name = ""
      @Current = {}
      @Providers = Convert.convert(
        Builtins.union(_Provs, providers),
        :from => "map",
        :to   => "map <string, map>"
      )
      @OriginalProviders = nil

      nil
    end

    # Export data
    # @return dumped settings (later acceptable by Import())
    def Export(type)
      return {} if !CheckType(type)
      _Provs = Filter(@Providers, type)
      Builtins.y2debug("Provs=%1", _Provs)
      deep_copy(_Provs)
    end

    # Select the given system provider
    # @param [Yast::Path] name SCR path to the system provider
    # @return true if success
    def SelectSystem(name)
      Builtins.y2debug("name=%1", name)

      @Name = Builtins.sformat("%1", name)
      if Builtins.findlastof(@Name, ".") != -1
        @Name = Builtins.regexpsub(@Name, "^.*\\.([^.]*)", "\\1")
      end
      @Name = "" if @Name == nil

      if "\"" == Builtins.substring(@Name, 0, 1)
        @Name = Builtins.substring(
          @Name,
          1,
          Ops.subtract(Builtins.size(@Name), 2)
        )
      end

      values = SCR.Dir(name)
      @Current = Builtins.listmap(values) do |value|
        { value => SCR.Read(Builtins.add(name, value)) }
      end

      Builtins.y2debug("Name=%1", @Name)
      Builtins.y2debug("Current=%1", @Current)

      true
    end

    # Select the given provider
    # @param [String] name provider to select ("" for new provider, default values)
    # @return true if success
    def Select(name)
      @Name = ""
      @Current = {}

      Builtins.y2debug("name=%1", name)
      if name != "" && !Builtins.haskey(@Providers, name)
        Builtins.y2error("No such provider: %1", name)
        return false
      end

      @Name = name
      @Current = Builtins.eval(Ops.get(@Providers, @Name, {}))
      @Type = ProviderType() if name != ""

      if @Current == {}
        # Default provider map
        @Current =
          # FIXME: remaining items
          {}

        # Variable key -> not functional #16701
        Ops.set(@Current, Ops.add(Builtins.toupper(@Type), "SUPPORTED"), "yes")
      end

      Builtins.y2debug("Name=%1", @Name)
      Builtins.y2debug("Type=%1", @Type)
      Builtins.y2debug("Current=%1", @Current)

      true
    end

    # Add a new provider
    # @param [String] type provider type (modem|isdn|dsl)
    # @return true if success
    def Add(type)
      @operation = nil
      return false if !CheckType(type)
      @Type = type
      return false if Select("") != true
      return false if CloneProvider() != true
      @LastCountry = @country
      @operation = :add
      true
    end

    # Edit the given provider
    # @param [String] name provider to edit
    # @return true if success
    def Edit(name)
      @operation = nil
      @Type = ""
      return false if Select(name) != true
      @LastCountry = "_custom"
      @operation = :edit
      true
    end

    # Delete the given provider
    # @param [String] name provider to delete
    # @return true if success
    def Delete(name)
      @operation = nil

      Builtins.y2debug("Delete(%1)", name)
      if !Builtins.haskey(@Providers, name)
        Builtins.y2error("Key not found: %1", name)
        return false
      end

      @Name = name
      @operation = :delete
      true
    end

    # Commit pending operation
    # @return true if success
    def Commit
      Builtins.y2debug("operation=%1", @operation)

      if @operation == :add || @operation == :edit
        Builtins.y2debug("Providers=%1", @Providers)
        Ops.set(@Providers, @Name, @Current)
        Builtins.y2debug("Providers=%1", @Providers)
      elsif @operation == :delete
        if !Builtins.haskey(@Providers, @Name)
          Builtins.y2error("Key not found: %1", @Name)
          return false
        end
        @Providers = Builtins.remove(@Providers, @Name)
        Ops.set(@Deleted, Builtins.size(@Deleted), @Name)
      else
        Builtins.y2error("Unknown operation: %1 (%2)", @operation, @Name)
        return false
      end

      @Name = ""
      @Type = ""
      @Current = {}
      @operation = nil
      @LastCountry = @country
      Builtins.y2debug("LastCountry=%1", @LastCountry)
      true
    end

    # Clone the given provider
    # @param [String] name provider to clone
    # @return true if success
    def Clone(name)
      @operation = nil
      return false if Select(name) != true
      return false if CloneProvider() != true
      @operation = :add
      true
    end

    # Clone the given system provider
    # @param [Yast::Path] name SCR path to system provider to clone
    # @return true if success
    def CloneSystem(name)
      @operation = nil
      return false if SelectSystem(name) != true
      return false if CloneProvider() != true
      @operation = :add
      true
    end
    def CloneProvider
      fullname = Ops.get_string(@Current, "PROVIDER", "")
      Builtins.y2debug("fullname=%1", fullname)

      # Split possible (1) from the end
      if Builtins.regexpmatch(fullname, " \\([0-9]+\\)$")
        fullname = Builtins.regexpsub(fullname, "(.*) \\([0-9]+\\)$", "\\1")
        Builtins.y2debug("fullname=%1", fullname)
      end

      # Generate unique full name (Current["PROVIDER"])
      suffix = 0
      gen = fullname
      forbidden = Builtins.maplist(@Providers) do |k, v|
        Ops.get_string(v, "PROVIDER", "")
      end
      while Builtins.contains(forbidden, gen)
        suffix = Ops.add(suffix, 1)
        gen = Builtins.sformat("%1 (%2)", fullname, suffix)
      end
      Ops.set(@Current, "PROVIDER", gen)
      Builtins.y2debug("fullname=%1", gen)

      # Generate unique Name
      suffix = 0
      name = @Name
      Builtins.y2debug("Name=%1", @Name)

      # Split possible number from the end
      if Builtins.regexpmatch(name, "[0-9]+$")
        name = Builtins.regexpsub(name, "(.*)[0-9]+", "\\1")
        Builtins.y2debug("name=%1", name)
      end

      # Sensible defaults for new providers
      gen = name
      if gen == ""
        gen = "provider0"
        name = "provider"
      end
      gen = "provider0" if gen == "provider"

      # Generate unique name (Name)
      forbidden = Map.Keys(@Providers)
      while Builtins.contains(forbidden, gen)
        suffix = Ops.add(suffix, 1)
        gen = Builtins.sformat("%1%2", name, suffix)
      end
      @Name = gen
      Builtins.y2debug("Name=%1", @Name)

      true
    end

    # Create an overview table with all configured providers
    # @return table items
    def Overview(type)
      return [] if !CheckType(type)
      _Provs = Convert.convert(
        Filter(@Providers, type),
        :from => "map",
        :to   => "map <string, map <string, string>>"
      )
      Builtins.y2debug("Provs=%1", _Provs)

      overview = []
      Builtins.maplist(_Provs) do |name, provmap|
        Builtins.y2debug("provider(%1): %2", name, provmap)
        it = {
          "id"          => name,
          "table_descr" => [name, Ops.get_string(provmap, "PROVIDER", "")]
        }
        if type != "dsl"
          Ops.set(
            it,
            "table_descr",
            Builtins.add(
              Ops.get_list(it, "table_descr", []),
              Ops.get_string(provmap, "PHONE", "")
            )
          )
        end
        # build the rich text:
        rich = Ops.add(
          Ops.add(
            HTML.Bold(
              # translators: Header of a rich text description for a provider
              # %1 is the provider name, %2 is the homepage
              Builtins.sformat(
                "%1 (%2)",
                Ops.get_string(provmap, "PROVIDER", ""),
                Ops.get_locale(provmap, "HOMEPAGE", _("No home page"))
              )
            ),
            "<br>"
          ),
          HTML.List(
            [
              Builtins.sformat(
                _("Product Name: %1"),
                Ops.get_locale(provmap, "PRODUCT", _("Unknown"))
              ),
              Builtins.sformat(
                _("Username: %1"),
                Ops.get_string(provmap, "USERNAME", "")
              )
            ]
          )
        )
        Ops.set(it, "rich_descr", rich)
        overview = Builtins.add(overview, it)
      end
      Builtins.y2debug("overview=%1", overview)

      deep_copy(overview)
    end

    # Create a textual summary and a list of unconfigured providers
    # @param [Boolean] split split configured and unconfigured?
    # @return summary of the current configuration
    def Summary(type, split)
      return [] if !CheckType(type)
      _Provs = Convert.convert(
        Filter(@Providers, type),
        :from => "map",
        :to   => "map <string, map <string, string>>"
      )
      Builtins.y2debug("Provs=%1", _Provs)

      summary = ""
      if Ops.less_than(Builtins.size(_Provs), 1)
        # Summary text
        summary = Summary.AddHeader("", _("Nothing is configured."))
      else
        # Summary text
        summary = Summary.AddHeader("", _("Configured Providers:"))
      end

      provs = []
      Builtins.maplist(_Provs) do |name, provmap|
        # Summary text description (%1 is provider name)
        descr = Builtins.sformat(_("Configured as %1"), name)
        phone = Ops.get_string(provmap, "PHONE", "")
        if phone != "" && phone != nil
          # Summary text description (%1 is provider name)
          descr = Builtins.sformat(
            _("Configured as %1 (phone %2)"),
            name,
            phone
          )
        end
        provs = Builtins.add(
          provs,
          Summary.Device(Ops.get_string(provmap, "PROVIDER", ""), descr)
        )
      end
      summary = Summary.DevicesList(provs)

      [
        summary,
        [
          # List item to providers summary
          Item(Id("modem"), _("Modem Provider"), true),
          # List item to providers summary
          Item(Id("isdn"), _("ISDN Provider")),
          # List item to providers summary
          Item(Id("dsl"), _("DSL Provider"))
        ]
      ]
    end

    # Get list of countries
    # @return [Array] for SelectionBox
    def GetCountries
      deep_copy(@Countries)
    end

    # Check if provider name is unique
    # @param [String] name provider name
    # @return true if OK
    def IsUnique(name)
      forbidden = Builtins.maplist(@Providers) do |k, v|
        Ops.get_string(v, "PROVIDER", "")
      end
      !Builtins.contains(forbidden, name)
    end

    # Return current provider type
    # @return current provider type
    def ProviderType
      supp = Builtins.filter(@Supported) do |t|
        Ops.get_string(
          @Current,
          Builtins.toupper(Ops.add(t, "SUPPORTED")),
          "no"
        ) == "yes"
      end
      Builtins.y2debug("supp=%1", supp)
      Ops.get_string(supp, 0, "modem")
    end

    #-------------------------------------------------------------------
    # FIXME FIXME FIXME FIXME FIXME FIXME FIXME FIXME FIXME FIXME FIXME
    #-------------------------------------------------------------------

    # Filter providers based on the type
    # @param [Array] provs list of providers
    # @param [String] type desired type "modem"|"isdn"|"rawip"|"syncppp"|"dsl"
    # @return [Array] of type capable providers
    def FilterProviders(provs, type)
      provs = deep_copy(provs)
      Builtins.y2debug("provs,type=%1,%2", provs, type)
      supported = Ops.add(Builtins.toupper(type), "SUPPORTED")
      etst = false
      if type == "rawip" || type == "syncppp"
        supported = "ISDNSUPPORTED"
        etst = true
      end
      Builtins.y2debug("supported=%1", supported)

      Builtins.filter(provs) do |i|
        Builtins.y2debug("i=%1", i)
        if Ops.is_string?(i)
          p = Ops.get(@Providers, Convert.to_string(i), {})
          if Ops.get_string(p, supported, "no") == "yes"
            if etst
              next Ops.get_string(p, "ENCAP", "_nodef") == type
            else
              next true
            end
          else
            next false
          end
        elsif SCR.Read(
            Ops.add(
              Convert.to_path(i),
              Builtins.topath(Ops.add(".", supported))
            )
          ) == "yes"
          if etst
            next SCR.Read(
              Ops.add(Convert.to_path(i), Builtins.topath(".ENCAP"))
            ) == type
          else
            next true
          end
        else
          next false
        end
      end
    end

    # Sorts providers alphabeticly (non-case-sensitively) and by priority.
    # In the first step, priority and name of each provider is obtained.
    # List of strings built from these values is created. Item lists are:
    # "<1-character-priority><34-characters-provider-name><provider-identifier>"
    # This list is sorted, result is correctly sorted, by priority and
    # alphabeticaly. I did not use builtin sort with sort code because it
    # uses bubble sort -- it was bloody slow.
    #
    # @param [Array] provs list of providers
    # @return sorted list of providers
    def SortProviders(provs)
      provs = deep_copy(provs)
      pre = Builtins.sort(Builtins.maplist(Builtins.add(provs, "--")) do |i|
        next "9                                  .\"--\"" if "--" == i
        if Ops.is_string?(i)
          next Ops.add(
            "x                                  ",
            Convert.to_string(i)
          )
        else
          tmp = Convert.to_string(
            SCR.Read(Ops.add(Convert.to_path(i), path(".PRIORITY")))
          )
          tmp = "-1" if nil == tmp
          p = Ops.subtract(8, Builtins.tointeger(tmp))
          if Ops.less_than(p, 0) || Ops.greater_than(p, 9)
            Builtins.y2error(
              "Wrong priority (%1), you must change the algorithm! [%2]",
              p,
              tmp
            )
          end
          tmp = Ops.add(
            Builtins.tolower(
              Convert.to_string(
                SCR.Read(Ops.add(Convert.to_path(i), path(".PROVIDER")))
              )
            ),
            "                                   "
          )
          tmp = Ops.add(Builtins.sformat("%1", p), tmp)
          next Builtins.sformat("%1%2", Builtins.substring(tmp, 0, 35), i)
        end
      end)
      if ".\"--\"" == Builtins.substring(Ops.get_string(pre, 0, ""), 35)
        pre = Builtins.remove(pre, 0)
      end
      Builtins.maplist(
        Convert.convert(pre, :from => "list", :to => "list <string>")
      ) do |i|
        next Builtins.substring(i, 35) if "x" == Builtins.substring(i, 0, 1)
        Builtins.topath(Builtins.substring(i, 35))
      end
    end

    # Get providers from a group (country/other)
    # @param [String] country we want providers from this country
    # @param [String] preselect preselect this provider
    # @return [Array] of items for SelectionBox
    def GetProviders(type, country, preselect)
      provs = []

      Builtins.y2debug("%1-%2", country, preselect)
      # Custom providers
      if country == "_custom"
        Builtins.foreach(@Providers) do |k, v|
          Ops.set(provs, Builtins.size(provs), k)
        end
      else
        dir = SCR.Dir(Builtins.add(path(".providers.s"), country))
        base = Builtins.add(path(".providers.v"), country)
        provs = Builtins.maplist(dir) { |i| Builtins.add(base, i) }
      end

      Builtins.y2debug("type=%1", type)
      Builtins.y2debug("provs=%1", provs)
      # Filter only desired providers
      provs = [] if provs == nil
      provs = FilterProviders(provs, type)

      Builtins.y2debug("provs=%1", provs)
      # Sort and create divider (line)
      provs = SortProviders(provs)

      Builtins.y2debug("provs=%1", provs)
      index = -1
      # i is either string or path
      Builtins.maplist(provs) do |i|
        index = Ops.add(index, 1)
        if Ops.is_string?(i)
          next Item(
            Id(i),
            Ops.get(@Providers, [Convert.to_string(i), "PROVIDER"], i),
            index == 0 || preselect == i
          )
        elsif path(".\"--\"") == i
          next Item(Id(i), "----------------")
        else
          next Item(
            Id(i),
            SCR.Read(Ops.add(Convert.to_path(i), path(".PROVIDER"))),
            0 == index
          )
        end
      end
    end

    publish :variable => :Name, :type => "string"
    publish :variable => :Current, :type => "map"
    publish :variable => :Type, :type => "string"
    publish :variable => :LastCountry, :type => "string"
    publish :function => :ProviderType, :type => "string ()"
    publish :function => :GetCountry, :type => "string ()"
    publish :function => :Modified, :type => "boolean (string)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean (string)"
    publish :function => :Import, :type => "map (string, map)"
    publish :function => :Export, :type => "map (string)"
    publish :function => :SelectSystem, :type => "boolean (path)"
    publish :function => :Select, :type => "boolean (string)"
    publish :function => :Add, :type => "boolean (string)"
    publish :function => :Edit, :type => "boolean (string)"
    publish :function => :Delete, :type => "boolean (string)"
    publish :function => :Commit, :type => "boolean ()"
    publish :function => :Clone, :type => "boolean (string)"
    publish :function => :CloneSystem, :type => "boolean (path)"
    publish :function => :Overview, :type => "list (string)"
    publish :function => :Summary, :type => "list (string, boolean)"
    publish :function => :GetCountries, :type => "list ()"
    publish :function => :IsUnique, :type => "boolean (string)"
    publish :function => :GetProviders, :type => "list (string, string, string)"
  end

  Provider = ProviderClass.new
  Provider.main
end
