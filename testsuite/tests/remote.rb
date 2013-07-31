# encoding: utf-8

module Yast
  class RemoteClient < Client
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

      Yast.import "Remote"

      # currently used default server_args from Xvnc package
      @default_server_args = "-noreset -inetd -once -query localhost -geometry 1024x768 -depth 16"
      @none_result = Builtins.sformat("-securitytypes %1", Remote.SEC_NONE)

      # empty args
      @server_args_empty = ""
      # default args from Xvnc
      @server_args_0 = @default_server_args
      # two dashes, upper case in option value
      @server_args_1 = "--securityTypes=VNCAUTH"
      # securitytypes present twice, camel case in option name.
      @server_args_2 = "securityTypes=VNCAUTH -rfbauth /var/lib/nobody/.vnc/passwd -securitytypes=vncauth"
      # space separated option and value
      @server_args_3 = Ops.add("-securitytypes none ", @default_server_args)

      # ********** Remote::SetSecurityType ********** //

      Assert.Equal(
        @none_result,
        Remote.SetSecurityType(@server_args_empty, Remote.SEC_NONE)
      )
      Assert.Equal(
        Builtins.sformat("%1 %2", @default_server_args, @none_result),
        Remote.SetSecurityType(@server_args_0, Remote.SEC_NONE)
      )
      Assert.Equal(
        @none_result,
        Remote.SetSecurityType(@server_args_1, Remote.SEC_NONE)
      )
      Assert.Equal(
        Builtins.sformat(
          "-rfbauth /var/lib/nobody/.vnc/passwd %1",
          @none_result
        ),
        Remote.SetSecurityType(@server_args_2, Remote.SEC_NONE)
      )
      Assert.Equal(
        Builtins.sformat("%1 %2", @default_server_args, @none_result),
        Remote.SetSecurityType(@server_args_3, Remote.SEC_NONE)
      )

      Assert.Equal(
        @server_args_empty,
        Remote.SetSecurityType(@server_args_empty, "INVALID")
      )
      Assert.Equal(
        @default_server_args,
        Remote.SetSecurityType(@default_server_args, "INVALID")
      )

      nil
    end
  end
end

Yast::RemoteClient.new.main
