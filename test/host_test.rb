#!/usr/bin/env rspec

require_relative "test_helper"

require "yast"
require "yast2/target_file"
require "cfa/memory_file"
require "cfa/base_model"
require "cfa/hosts"

Yast.import "Host"
Yast.import "DNS"

describe Yast::Host do
  let(:file) do
    file_path = File.join(DATA_PATH, "hosts")
    CFA::MemoryFile.new(File.read(file_path))
  end

  let(:lan_config) do
    double("lan_config").as_null_object
  end

  around do |test|
    # use only testing file
    CFA::BaseModel.default_file_handler = file

    test.call

    CFA::BaseModel.default_file_handler = Yast::TargetFile
  end

  before do
    allow(Yast::Lan).to receive(:yast_config).and_return(lan_config)
    allow(Yast::SCR).to receive(:Read).with(path(".target.size"), "/etc/hosts").and_return(50)
    allow(Y2Network::Sysconfig::TypeDetector)
      .to receive(:type_of)
      .with(/eth[0-9]/)
      .and_return(Y2Network::InterfaceType::ETHERNET)

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
    context "settings have not been modified" do
      it "does nothing" do
        expect(file).to_not receive(:write)
        Yast::Host.Write
      end

      it "does nothing although system settings have been read" do
        expect(file).to_not receive(:write)
        Yast::Host.Read
        Yast::Host.Write
      end
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

  describe ".Import" do
    let(:file) do
      file_path = File.join(DATA_PATH, "default_hosts")
      CFA::MemoryFile.new(File.read(file_path))
    end

    let(:etc_hosts) do
      {
        "127.0.0.1" => ["localhost"],
        "::1"       => ["localhost ipv6-localhost ipv6-loopback"],
        "fe00::0"   => ["ipv6-localnet"],
        "ff00::0"   => ["ipv6-mcastprefix"],
        "ff02::1"   => ["ipv6-allnodes"],
        "ff02::2"   => ["ipv6-allrouters"],
        "ff02::3"   => ["ipv6-allhosts"]
      }
    end

    it "loads the current '/etc/hosts' entries" do
      Yast::Host.Import("hosts" => {})

      expect(Yast::Host.name_map).to eql(etc_hosts)
    end

    it "merges current entries with the given ones" do
      Yast::Host.Import("hosts" => { "10.20.1.29" => ["beholder"] })

      expect(Yast::Host.name_map).to eql(etc_hosts.merge("10.20.1.29" => ["beholder"]))
    end

    context "when the profile contains multiple host entries for ::1" do
      let(:holder_entries) { ["beholder.test.com test.com", "second.test.com second"] }
      let(:hosts) do
        {
          "::1"        => ["localhost", "ipv6-localhost", "ipv6-loopback"],
          "10.20.1.29" => holder_entries
        }
      end

      it "converts each duplicated entry to just one line" do
        Yast::Host.Import("hosts" => hosts)

        expect(Yast::Host.name_map["10.20.1.29"]).to eql([holder_entries.join(" ")])
      end
    end

    context "import an emtpy host section" do
      let(:org_etx_hosts) { file.content }

      before do
        Yast::Host.Import("hosts" => {})
      end

      it "does not reset /etc/hosts" do
        expect(file).to receive(:write).with(
          "/etc/hosts", file.content
        )
        Yast::Host.Write
      end
    end
  end

  describe ".Export" do
    let(:file) do
      file_path = File.join(DATA_PATH, "default_hosts")
      CFA::MemoryFile.new(File.read(file_path))
    end

    let(:etc_hosts) do
      {
        "127.0.0.1"  => ["localhost localhost.localdomain"],
        "::1"        => ["localhost ipv6-localhost ipv6-loopback"],
        "fe00::0"    => ["ipv6-localnet"],
        "ff00::0"    => ["ipv6-mcastprefix"],
        "ff02::1"    => ["ipv6-allnodes"],
        "ff02::2"    => ["ipv6-allrouters"],
        "ff02::3"    => ["ipv6-allhosts"],
        "10.20.1.29" => ["beholder"]
      }
    end

    it "Successfully exports stored mapping" do
      Yast::Host.Import("hosts" => etc_hosts)
      expect(Yast::Host.Export).to eql("hosts" => etc_hosts)
    end

    it "removes empty name lists" do
      Yast::Host.Import("hosts" => { "127.0.0.1" => ["localhost localhost.localdomain"], "10.20.1.29" => [] })
      etc_hosts.delete("10.20.1.29")

      expect(Yast::Host.Export).to eql("hosts" => etc_hosts)
    end

    it "exports empty hash when no mapping is defined" do
      Yast::Host.Import(
        "hosts" => {
          "127.0.0.1" => [],
          "::1"       => [],
          "fe00::0"   => [],
          "ff00::0"   => [],
          "ff02::1"   => [],
          "ff02::2"   => [],
          "ff02::3"   => []
        }
      )
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

    it "raises an error when empty ip is provided" do
      expect { Yast::Host.Update("oldhostname", "newhostname", "") }
        .to raise_error(ArgumentError, instance_of(String))
    end

    it "raises an error when nil ip is provided" do
      expect { Yast::Host.Update("oldhostname", "newhostname", nil) }
        .to raise_error(ArgumentError, instance_of(String))
    end

    it "doesn't write entry with duplicate hostname" do
      ip = "1.1.1.1"
      hostname = "linux"

      Yast::Host.Update(hostname, hostname, ip)
      expect(Yast::Host.name_map[ip]).not_to eql ["#{hostname} #{hostname}"]
    end

    it "doesn't write entry with duplicate hostname" do
      ip = "1.1.1.1"
      hostname = "linux"

      Yast::Host.Update(hostname, hostname, [ip])
      expect(Yast::Host.name_map[ip]).not_to eql ["#{hostname} #{hostname}"]
    end
  end

  describe ".ResolveHostnameToStaticIPs" do
    let(:static_ips) { ["1.1.1.1", "2.2.2.2"] }
    let(:fqhostname) { "sles.suse.de" }

    before(:each) do
      allow(Yast::Host)
        .to receive(:StaticIPs)
        .and_return(static_ips)
      allow(Yast::Hostname).to receive(:MergeFQ).and_return(fqhostname)
    end

    it "doesn't call .Update when an IP already has a hostname" do
      hostname = "linux"

      Yast::Host.Update(hostname, hostname, [static_ips[0]])

      expect(Yast::Host)
        .not_to receive(:Update)
        .with(fqhostname, fqhostname, static_ips)

      Yast::Host.ResolveHostnameToStaticIPs
    end
  end

  describe ".EnsureHostnameResolvable" do
    context "need dummy ip" do
      before do
        allow(Yast::DNS).to receive(:write_hostname).and_return(true)
        allow(Yast::DNS).to receive(:hostname).and_return("localmachine")
        allow(Yast::DNS).to receive(:domain).and_return("domain.local")
        Yast::Host.Read
      end

      it "sets entry for 127.0.0.2 to hostname and hostname with domain" do
        Yast::Host.EnsureHostnameResolvable
        Yast::Host.Write

        content = file.content

        expect(content.lines).to include("127.0.0.2\tlocalmachine.domain.local localmachine\n")
      end

      it "sets Host as modified" do
        expect { Yast::Host.EnsureHostnameResolvable }
          .to change { Yast::Host.GetModified }
          .from(false).to(true)
      end
    end

    context "do not need dummy ip" do
      before do
        allow(Yast::DNS).to receive(:write_hostname).and_return(false)
        Yast::Host.Read
      end

      context "and 127.0.0.2 is present in /etc/hosts" do
        it "deletes entry for 127.0.0.2" do
          Yast::Host.EnsureHostnameResolvable
          Yast::Host.Write

          content = file.content

          expect(content.lines.grep(/^127.0.0.2/)).to be_empty
        end

        it "sets Host as modified" do
          expect { Yast::Host.EnsureHostnameResolvable }
            .to change { Yast::Host.GetModified }
            .from(false).to(true)
        end
      end
    end

    context "and /etc/hosts does not contains 127.0.0.2 entry" do
      let(:file) do
        file_path = File.join(DATA_PATH, "default_hosts")
        CFA::MemoryFile.new(File.read(file_path))
      end

      before do
        allow(Yast::DNS).to receive(:write_hostname).and_return(false)
        Yast::Host.Read
      end

      it "does not set Host as modified" do
        expect { Yast::Host.EnsureHostnameResolvable }
          .not_to change { Yast::Host.GetModified }.from(false)
      end
    end
  end

  describe ".ResolveHostnameToStaticIPs" do
    let(:static_ips) { ["1.1.1.1", "2.2.2.2"] }
    let(:fqhostname) { "sles.suse.de" }

    before(:each) do
      allow(Yast::Host)
        .to receive(:StaticIPs)
        .and_return(static_ips)
      allow(Yast::Hostname).to receive(:MergeFQ).and_return(fqhostname)
    end

    it "do not send array of IPs into .Update" do # bnc1038521
      expect(Yast::Host)
        .not_to receive(:Update)
        .with(instance_of(String), instance_of(String), instance_of(Array))

      Yast::Host.ResolveHostnameToStaticIPs
    end

    it "doesn't call .Update when an IP already has a hostname" do
      hostname = "linux"

      Yast::Host.Update(hostname, hostname, static_ips[0])

      expect(Yast::Host)
        .not_to receive(:Update)
        .with(fqhostname, fqhostname, static_ips[0])

      Yast::Host.ResolveHostnameToStaticIPs
    end
  end

  describe ".StaticIPs" do
    before(:each) do
      devs = {
        "lo"   => {
          "BOOTPROTO" => "static",
          "IPADDR"    => "127.0.0.1"
        },
        "eth0" => { "BOOTPROTO" => "static" },
        "eth1" => { "BOOTPROTO" => "dhcp" },
        "eth2" => {
          "BOOTPROTO" => "static",
          "IPADDR"    => "1.1.1.1"
        },
        "eth3" => {
          "BOOTPROTO" => "static",
          "IPADDR"    => ""
        }
      }

      # do not touch system
      allow(Yast::NetworkInterfaces)
        .to receive(:Read)

      devs.each do |dev, conf|
        allow(Yast::NetworkInterfaces)
          .to receive(:Locate)
          .and_return(devs.keys)
        allow(Yast::NetworkInterfaces)
          .to receive(:GetValue)
          .with(dev, "IPADDR")
          .and_return(conf["IPADDR"])
      end
    end

    it "do not return invalid items for devices with static configuration but invalid IP" do
      expect(Yast::Host.StaticIPs).not_to include ""
      expect(Yast::Host.StaticIPs).not_to include nil
      expect(Yast::Host.StaticIPs).not_to include "127.0.0.1"
    end

    it "returns all devices with valid setup" do
      expect(Yast::Host.StaticIPs).to include "1.1.1.1"
    end
  end
end
