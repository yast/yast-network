#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "cfa/memory_file"
require "cfa/base_model"
require "cfa/hosts"

Yast.import "Host"

describe Yast::Host do
  let(:file) do
    file_path = File.expand_path("../data/hosts", __FILE__)
    CFA::MemoryFile.new(File.read(file_path))
  end

  before do
    # use only testing file
    CFA::BaseModel.default_file_handler = file

    allow(Yast::SCR).to receive(:Read).with(path(".target.size"), "/etc/hosts").and_return(50)

    # reset internal caches
    Yast::Host.instance_variable_set(:"@modified", false)
    Yast::Host.instance_variable_set(:"@initialized", false)

    # do nothing on system
    allow(Yast::Execute).to receive(:on_target)
  end

  describe ".Read" do
    it "reads hosts configuration from system" do
      Yast::Host.Read

      expect(Yast::Host.name_map).to_not be_empty
    end
  end

  describe ".clear" do
    it "removes all entries from host table" do
      Yast::Host.Read
      Yast::Host.clear

      expect(Yast::Host.name_map).to be_empty
    end
  end

  describe ".name_map" do
    # FIXME: make value API better
    it "returns hash with ip as key and hostnames as value" do
      Yast::Host.Read

      name_map = Yast::Host.name_map
      expect(name_map["10.100.128.72"]).to eq(["pepa.labs.suse.cz pepa pepa2"])
    end
  end

  describe ".names" do
    it "returns empty array if given ip is not is hosts table" do
      Yast::Host.Read

      expect(Yast::Host.names("1.1.1.1")).to eq []
    end

    # FIXME: better API
    it "returns single element array with string containing canonical name and aliases separated by space" do
      Yast::Host.Read

      expect(Yast::Host.names("10.100.128.72")).to eq(["pepa.labs.suse.cz pepa pepa2"])
    end
  end

  describe ".add_name" do
    it "adds host to hosts entry even if it is already there" do
      Yast::Host.Read
      Yast::Host.add_name("10.100.128.72", "test test2.suse.cz")
      Yast::Host.add_name("10.100.128.72", "test3 test3.suse.cz")

      expect(Yast::Host.names("10.100.128.72")).to eq([
                                                        "pepa.labs.suse.cz pepa pepa2",
                                                        "test test2.suse.cz",
                                                        "test3 test3.suse.cz"
                                                      ])
    end
  end

  describe ".Write" do
    it "do nothing if not modified" do
      expect(file).to_not receive(:write)
      Yast::Host.Read
      Yast::Host.Write
    end

    it "writes content of file" do
      Yast::Host.Read
      Yast::Host.add_name("10.100.128.72", "test test2.suse.cz")
      Yast::Host.add_name("10.100.128.72", "test3 test3.suse.cz")
      Yast::Host.Write

      content = file.content

      expect(content.lines).to include("10.100.128.72\ttest test2.suse.cz\n")
      expect(content.lines).to include("10.100.128.72\ttest3 test3.suse.cz\n")
    end

    it "creates backup of file" do
      expect(Yast::Execute).to receive(:on_target).with("cp", "/etc/hosts", "/etc/hosts.YaST2save")

      Yast::Host.Read
      Yast::Host.add_name("10.100.128.72", "test test2.suse.cz")
      Yast::Host.add_name("10.100.128.72", "test3 test3.suse.cz")
      Yast::Host.Write
    end
  end

  describe ".Export" do
    let(:etc_hosts) do
      {
        "127.0.0.1"  => ["localhost localhost.localdomain"],
        "10.20.1.29" => ["beholder"]
      }
    end

    it "Successfully exports stored mapping" do
      Yast::Host.Import("hosts" => etc_hosts)
      expect(Yast::Host.Export).to eql("hosts" => etc_hosts)
    end

    it "removes empty name lists" do
      Yast::Host.Import("hosts" => { "127.0.0.1" => ["localhost"], "10.0.0.1" => [] })
      expect(Yast::Host.Export).to eql("hosts" => { "127.0.0.1" => ["localhost"] })
    end

    it "exports empty hash when no mapping is defined" do
      Yast::Host.Import("hosts" => {})
      expect(Yast::Host.Export).to be_empty
    end
  end

  describe ".Update" do
    let(:etc_hosts) do
      {
        "127.0.0.1" => ["localhost localhost.localdomain"],
        "10.0.0.1"  => ["somehost.example.com  notice-two-spaces"]
      }
    end

    let(:etc_hosts_new) do
      {
        "127.0.0.1" => ["localhost localhost.localdomain"],
        "10.0.0.1"  => ["somehost.example.com notice-two-spaces"]
      }
    end

    it "doesn't drop records with two spaces but make it single space" do
      Yast::Host.Import("hosts" => etc_hosts)
      Yast::Host.Update("", "newname", "10.0.0.42")

      tested_ip = "10.0.0.1"
      expect(Yast::Host.name_map[tested_ip]).to eql etc_hosts_new[tested_ip]
    end

    it "adds alias for added hostname" do
      Yast::Host.Import("hosts" => etc_hosts)
      Yast::Host.Update("", "newname.suse.cz", "10.0.0.42")

      tested_ip = "10.0.0.42"
      expect(Yast::Host.name_map[tested_ip]).to eql ["newname.suse.cz newname"]
    end

    it "deletes old hostnames passed as first parameter" do
      Yast::Host.Read
      Yast::Host.Update("pepa.labs.suse.cz", "newname.suse.cz", "10.0.0.42")
      Yast::Host.Write

      content = file.content

      expect(content.lines).to include("10.100.128.72   pepa pepa2\n")
      expect(content.lines).to include("10.0.0.42\tnewname.suse.cz newname\n")
    end

    it "adds hostname as alias if ip have already its entry" do
      Yast::Host.Read
      Yast::Host.Update("pepa.labs.suse.cz", "newname.suse.cz", "10.100.128.72")
      Yast::Host.Write

      content = file.content

      expect(content.lines).to include("10.100.128.72   pepa pepa2 newname.suse.cz newname\n")
    end
  end

  describe ".EnsureHostnameResolvable" do
    context "need dummy ip" do
      before do
        allow(Yast::DNS).to receive(:write_hostname).and_return(true)
      end

      it "sets entry for 127.0.0.2 to hostname and hostname with domain" do
        allow(Yast::DNS).to receive(:hostname).and_return("localmachine")
        allow(Yast::DNS).to receive(:domain).and_return("domain.local")
        Yast::Host.Read
        Yast::Host.EnsureHostnameResolvable
        Yast::Host.Write

        content = file.content

        expect(content.lines).to include("127.0.0.2\tlocalmachine.domain.local localmachine\n")
      end
    end

    context "do not need dummy ip" do
      before do
        allow(Yast::DNS).to receive(:write_hostname).and_return(false)
      end

      it "deletes entry for 127.0.0.2" do
        Yast::Host.Read
        Yast::Host.EnsureHostnameResolvable
        Yast::Host.Write

        content = file.content

        expect(content.lines.grep(/^127.0.0.2/)).to be_empty
      end

    end
  end
end
