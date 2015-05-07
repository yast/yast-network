# encoding: utf-8

module Yast
  class YaPIBondClient < Client
    def main
      Yast.import "Testsuite"
      Yast.import "Assert"

      @READ = {
        "init"      => { "scripts" => { "exists" => false } },
        "target"    => {
          "size"        => 27,
          "string"      => "laptop.suse.cz",
          "bash_output" => "laptop.suse.cz"
        },
        "probe"     => { "architecture" => "i386" },
        "sysconfig" => {
          "console" => { "CONSOLE_ENCODING" => "UTF-8" },
          "network" => {
            "config" => {
              "NETCONFIG_DNS_STATIC_SERVERS"    => "208.67.222.222 208.67.220.220",
              "NETCONFIG_DNS_STATIC_SEARCHLIST" => "suse.cz suse.de"
            },
            "dhcp"   => {
              "DHCLIENT_SET_HOSTNAME"   => "no",
              "WRITE_HOSTNAME_TO_HOSTS" => "no"
            }
          }
        },
        "routes"    => [
          { "destination" => "default", "gateway" => "10.20.30.40" }
        ]
      }

      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "laptop.suse.cz",
            "stderr" => ""
          }
        }
      }

      # configuration in form as expected on YaPI external interface (e.g. how WY sends it).
      # FIXME: Note that currently YaPI expects some options even if they are not used (e.g. bond_option)
      @net_ifaces_config = {
        "interface" => {
          "bond0" => {
            "bootproto"   => "static",
            "ipaddr"      => "4.3.2.1/24",
            "bond"        => "yes",
            "bond_slaves" => "eth1 eth2 eth3",
            "bond_option" => ""
          }
        }
      }

      Testsuite.Init([@READ, {}, @EXEC], nil)

      Yast.import "YaPI::NETWORK"

      @write_succeeded = { "error" => "", "exit" => "0" }

      Assert.Equal(@write_succeeded, YaPI::NETWORK.Write(@net_ifaces_config))

      nil
    end
  end
end

Yast::YaPIBondClient.new.main
