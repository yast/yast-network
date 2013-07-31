# encoding: utf-8

module Yast
  class DnsClient < Client
    def main
      Yast.import "Assert"
      Yast.import "Testsuite"

      @READ = {
        "probe"     => { "architecture" => "i386" },
        "sysconfig" => { "console" => { "CONSOLE_ENCODING" => "UTF-8" } }
      }

      @EXEC = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "charset=UTF-8",
            "stderr" => ""
          }
        }
      }

      @hostnames = [
        "127.0.0.1       localhost",
        "1.1.1.1         1-hostname alias",
        "2.2.2.2         hostname-2",
        "3.3.3.3         -invalid_hostname-",
        "9.114.214.42    9117-mma-1-lp1.pok.stglabs.ibm.com"
      ]

      Yast.import "DNS"

      Assert.Equal(
        "localhost",
        DNS.GetHostnameFromGetent(Ops.get(@hostnames, 0, ""))
      )
      Assert.Equal(
        "1-hostname",
        DNS.GetHostnameFromGetent(Ops.get(@hostnames, 1, ""))
      )
      Assert.Equal(
        "hostname-2",
        DNS.GetHostnameFromGetent(Ops.get(@hostnames, 2, ""))
      )
      Assert.Equal("", DNS.GetHostnameFromGetent(Ops.get(@hostnames, 3, "")))
      Assert.Equal(
        "9117-mma-1-lp1.pok.stglabs.ibm.com",
        DNS.GetHostnameFromGetent(Ops.get(@hostnames, 4, ""))
      )

      nil
    end
  end
end

Yast::DnsClient.new.main
