# encoding: utf-8

# ***************************************************************************
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
# **************************************************************************
# File:	clients/inst_do_net_test.ycp
# Package:	Network configuration
# Summary:	Configuration dialogs for installation
# Authors:	Michal Svec <msvec@suse.cz>
#		Arvin Schnell <arvin@suse.de>
#
module Yast
  class InstDoNetTestClient < Client
    def main
      Yast.import "Pkg"
      Yast.import "UI"

      textdomain "network"

      Yast.import "Directory"
      Yast.import "Internet"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Product"
      Yast.import "Wizard"
      Yast.import "PackageCallbacks"
      Yast.import "Proxy"
      Yast.import "GetInstArgs"
      Yast.import "Report"
      Yast.import "String"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/installation/dialogs.rb"

      # Called backwards
      return :auto if GetInstArgs.going_back

      if !Internet.do_test
        # no internet test - no suse register
        # suse register then only informs about its existence
        Internet.suse_register = false
        return :auto
      end

      Internet.suse_register = true

      @we_have_patches = false

      # do we have a connection already?
      # then don't open or close it, don't show respective steps
      @already_up = false

      # curl return code of downloading release notes
      # useful to tell apart misconfigured network
      # from server side error (#236371)
      @curl_ret_code = 0

      # subset of curl return codes, indicating misconfigured network
      @curl_ret_codes_bad = [
        5, # couldn't resolve proxy
        6, # couldn't resolve host
        7
      ] # couldn't connect()

      # Stage transitions in handle_stage:
      # open: wait (test), copy, finish (failure), wait
      # wait: copy (test), finish (failure), copy
      # copy: relnotes
      # relnotes: patches
      # patches: close
      # close: finish
      # finish
      @test_stage = :open

      @test_result = :success

      # list of all log files to show
      @logs = []

      # dir of log files
      # Formerly it was under tmpdir and thus got erased automatically.
      # Now we want to keep it (#46285), so let's put it under logdir.
      @logdir = Ops.add(Directory.logdir, "/internet-test")

      @already_up = Internet.Status if !Mode.test

      # Progress step 1/3
      @l1 = _("Connecting to Internet...")
      # Progress step 2/3
      @l2 = _("Downloading the latest release notes...")
      # Progress step 3/3
      @l4 = _("Closing connection...")

      # fix checkycp complaints
      @dash = "-   "
      @excl = "!   "

      # File names of downloaded release notes
      @release_notes_filenames = []

      # RPM names of downloaded release notes
      @release_notes_rpms = {}

      # --- internet test starts here ---

      # Create logdir
      if !Convert.to_boolean(SCR.Execute(path(".target.mkdir"), @logdir))
        Builtins.y2error("can't create logdir")
      end

      @ret = nil

      make_dialog

      Wizard.DisableBackButton
      Wizard.DisableAbortButton
      Wizard.DisableNextButton
      UI.ChangeWidget(Id(:abort_test), :Enabled, true)
      UI.ChangeWidget(Id(:view_log), :Enabled, false)

      UI.BusyCursor

      # loop during internet test

      SCR.Execute(
        path(".target.bash"),
        "/bin/logger BEGIN OF YAST2 INTERNET TEST"
      )

      loop do
        handle_stage

        break if @test_stage == :finish

        @ret = UI.TimeoutUserInput(250)

        next if @ret == :timeout

        if @ret == :abort_test
          Internet.Stop("") if !@already_up
          @test_result = :failure
          break
        end

        Builtins.y2error("Unexpected return code: %1", @ret)
      end

      SCR.Execute(
        path(".target.bash"),
        "/bin/logger END OF YAST2 INTERNET TEST"
      )

      show_result

      copy_logs2

      Wizard.EnableBackButton
      Wizard.DisableAbortButton
      Wizard.EnableNextButton
      # #105811, it lost focus when it was disabled
      Wizard.SetFocusToNextButton
      UI.ChangeWidget(Id(:abort_test), :Enabled, false)
      UI.ChangeWidget(Id(:view_log), :Enabled, true)

      UI.NormalCursor

      # --- internet test ends here ---

      # loop after internet test
      loop do
        @ret = UI.UserInput

        if @ret == :view_log
          ShowLogs(@logs, @logdir)
          next
        end

        if @ret == :abort || @ret == :cancel
          break if Popup.ConfirmAbort(:incomplete)
          next
        end

        break if @ret == :back || @ret == :next

        Builtins.y2error("Unexpected return code: %1", @ret)
      end

      # set internal data according the test result
      if @ret == :next
        Internet.suse_register = @test_result == :success

        # we don't check for patches here anymore
        #	if (we_have_patches)
        #	{
        #	    Internet::do_you = true;
        #	    // Removed due to integration of suse_register
        #	    // AskYOUDialog ();
        #	}
        #	else
        #	    Internet::do_you = false;
      end

      Convert.to_symbol(@ret)

      # EOF
    end

    # Return current language with .UTF-8 appended.
    # FIXME: there must be a better way!
    def GetLanguageUTF8
      tmp = WFM.GetLanguage
      pos = Builtins.findfirstof(tmp, "@.")
      tmp = Builtins.substring(tmp, 0, pos) if !pos.nil?
      Ops.add(tmp, ".UTF-8")
    end

    # Create the dialog contents
    def make_dialog
      # Test dialog caption
      caption = _("Running Internet Connection Test")

      # help for dialog "Running Internet Connection Test"
      help = _(
        "<p>Here, view the progress of the\nInternet connection test.</p>\n"
      ) +
        # help for dialog "Running Internet Connection Test"
        _("<p>The test can be aborted by pressing\n<b>Abort Test</b>.</p>\n")

      # In update mode there's no network setup, #50381
      # Actually it depends on the control file, but it's only a help text
      if !Mode.update
        help = Ops.add(
          help,
          # help for dialog "Running Internet Connection Test"
          _(
            "<p>If the test fails, return to the network configuration\nand correct the settings.</p>\n"
          )
        )
      end

      # Progress labels
      progress = VBox()

      # do not connect to internet when already connected
      if !@already_up
        progress = Builtins.add(
          progress,
          Left(HBox(Heading(Id(:s1), @dash), Label(@l1)))
        )
      end
      progress = Builtins.add(
        progress,
        Left(HBox(Heading(Id(:s2), @dash), Label(@l2)))
      )
      # do not shutdown the connection when already connected
      if !@already_up
        progress = Builtins.add(
          progress,
          Left(HBox(Heading(Id(:s3), @dash), Label(@l4)))
        )
      end

      progress = Builtins.add(progress, VStretch())

      progress = Builtins.add(
        progress,
        HBox(
          # Label for result of internet test
          Label(_("Test Result:")),
          HSpacing(2),
          Label(Id(:res), Opt(:outputField, :hstretch), "")
        )
      )

      progress = Builtins.add(progress, VSpacing(1))

      # Push Button to abort internet test
      progress = Builtins.add(
        progress,
        PushButton(Id(:abort_test), _("&Abort Test"))
      )

      # Frame label: status of internet test
      progress = Frame(
        _("Test Status"),
        VBox(VSpacing(1), HBox(HSpacing(1), progress, HSpacing(1)), VSpacing(1))
      )

      # Test dialog contents
      contents = VBox(
        VStretch(),
        VBox(HVCenter(HSquash(progress))),
        VStretch(),
        # Push Button to see logs of internet test
        PushButton(Id(:view_log), Opt(:disabled), _("&View Logs...")),
        VStretch()
      )

      Wizard.SetContents(caption, contents, help, true, true)
      Wizard.SetTitleIcon("yast-network")

      nil
    end

    # @param [Fixnum] i step number 1..4
    # @param [Symbol] s bullet: `arrow: current, `check: done, `dash: not done or failed
    def mark_label(i, s)
      widgets = [nil, :s1, :s2, :s3, :s4]
      bullets = {
        arrow: UI.Glyph(:BulletArrowRight),
        check: UI.Glyph(:CheckMark),
        dash:  @excl
      }

      if UI.WidgetExists(Id(Ops.get(widgets, i)))
        UI.ChangeWidget(
          Id(Ops.get(widgets, i)),
          :Value,
          Ops.get(bullets, s, "?")
        )
      else
        Builtins.y2error("No such widget with ID: %1", Ops.get(widgets, i))
      end

      nil
    end

    def show_result
      if @test_result == :success
        Internet.test = true
        # result of internet test
        UI.ChangeWidget(Id(:res), :Value, _("Success"))
      else
        Internet.test = false
        # result of internet test
        UI.ChangeWidget(Id(:res), :Value, _("Failure"))
      end

      nil
    end

    def copy_logs1
      # label of combobox where the log is selected
      @logs = Builtins.add(
        @logs,
        menuname: _("Kernel Network Interfaces"),
        filename: "ip_addr.log"
      )
      run_command = Ops.add(
        Ops.add("/sbin/ip addr show > '", String.Quote(@logdir)),
        "/ip_addr.log'"
      )
      ret_command = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          run_command,
          "LANG" => GetLanguageUTF8()
        )
      )
      if ret_command != 0
        Builtins.y2error("Command '%1' failed -> %2", run_command, ret_command)
      end

      # label of combobox where the log is selected
      @logs = Builtins.add(
        @logs,
        menuname: _("Kernel Routing Table"), filename: "ip_route.log"
      )
      run_command = Ops.add(
        Ops.add("/sbin/ip route show > '", String.Quote(@logdir)),
        "/ip_route.log'"
      )
      ret_command = Convert.to_integer(
        SCR.Execute(
          path(".target.bash"),
          run_command,
          "LANG" => GetLanguageUTF8()
        )
      )
      if ret_command != 0
        Builtins.y2error("Command '%1' failed -> %2", run_command, ret_command)
      end

      # label of combobox where the log is selected
      @logs = Builtins.add(
        @logs,
        menuname: _("Hostname Lookup"), filename: "resolv.conf"
      )
      run_command = Ops.add(
        Ops.add("/bin/cp /etc/resolv.conf '", String.Quote(@logdir)),
        "/resolv.conf'"
      )
      ret_command = Convert.to_integer(
        SCR.Execute(path(".target.bash"), run_command)
      )
      if ret_command != 0
        Builtins.y2error("Command '%1' failed -> %2", run_command, ret_command)
      end

      nil
    end

    def copy_logs2
      # label of combobox where the log is selected
      @logs = Builtins.add(
        @logs,
        menuname: _("Kernel Messages"), filename: "messages"
      )
      run_command = Ops.add(
        Ops.add(
          Ops.add(Directory.ybindir, "/cut-messages > '"),
          String.Quote(@logdir)
        ),
        "/messages'"
      )
      ret_command = Convert.to_integer(
        SCR.Execute(path(".target.bash"), run_command)
      )
      if ret_command != 0
        Builtins.y2error("Command '%1' failed -> %2", run_command, ret_command)
      end

      nil
    end

    def wait_for_test
      while SCR.Read(path(".background.output_open")) ||
          SCR.Read(path(".background.isrunning"))
        Builtins.sleep(100)

        ret = UI.PollInput

        next unless [:abort, :abort_test].include?(ret)

        # Abort pressed by the user
        Builtins.y2milestone("Test aborted by user")
        SCR.Execute(path(".background.kill"))
        return -1
      end

      # check the exit code of the test
      res = SCR.Read(path(".background.status"))

      Builtins.y2milestone("Command returned: %1", res)

      res
    end

    # Download all release notes mentioned in Product::relnotesurl_all
    #
    # @return true when successful
    def download_release_notes
      # At least one release notes downloaded means success
      # but the default is false in case of some release-notes
      # available for download
      # @see Bug #181094
      test_ret = false

      relnotes_counter = 0

      Product.relnotesurl_all = Builtins.toset(Product.relnotesurl_all)

      # #390738: only one URL now
      # works well with the list of all products
      Builtins.foreach(Product.relnotesurl_all) do |url|
        # protect from wrong urls
        if url.nil? || url == ""
          Builtins.y2warning("Skipping relnotesurl '%1'", url)
          next false
        end
        pos = Ops.add(Builtins.findlastof(url, "/"), 1)
        if pos.nil?
          Builtins.y2error("broken url for release notes: %1", url)
          next false
        end
        # Where we want to store the downloaded release notes
        filename = Builtins.sformat(
          "%1/%2-%3",
          Convert.to_string(SCR.Read(path(".target.tmpdir"))),
          relnotes_counter,
          Builtins.substring(url, pos)
        )
        # Package name
        Ops.set(@release_notes_rpms, filename, Builtins.substring(url, pos))
        Ops.set(
          @release_notes_rpms,
          filename,
          Builtins.regexpsub(
            Ops.get(@release_notes_rpms, filename, ".rpm"),
            "(.*).rpm",
            "\\1"
          )
        )
        # Where to store the curl log
        log_filename = Builtins.sformat("curl_%1.log", relnotes_counter)
        # Get proxy settings (if any)
        proxy = ""
        Proxy.Read
        # Test if proxy works
        if Proxy.enabled
          # it is enough to test http proxy, release notes are downloaded via http
          proxy_ret = Proxy.RunTestProxy(
            Proxy.http,
            "",
            "",
            Proxy.user,
            Proxy.pass
          )

          if Ops.get_boolean(proxy_ret, ["HTTP", "tested"], true) == true &&
              Ops.get_integer(proxy_ret, ["HTTP", "exit"], 1) == 0
            user_pass = if Proxy.user != ""
              Ops.add(Ops.add(Proxy.user, ":"), Proxy.pass)
            else
              ""
            end
            proxy = Ops.add(
              Ops.add("--proxy ", Proxy.http),
              if user_pass != ""
                Ops.add(Ops.add(" --proxy-user '", user_pass), "'")
              else
                ""
              end
            )
          end
        end
        # Include also proxy option (if applicable) - #162800, #260407
        cmd = Ops.add(
          "/usr/bin/curl --location --verbose --fail --max-time 300 ",
          Builtins.sformat(
            "%1 %2 --output '%3' > '%4/%5' 2>&1",
            proxy,
            url,
            String.Quote(filename),
            String.Quote(@logdir),
            String.Quote(log_filename)
          )
        )
        # env["LANG"] = GetLanguageUTF8 ();
        Builtins.y2milestone("Downloading release notes: %1", cmd)
        #	    SCR::Execute(.background.run, cmd);
        #	    integer ret = wait_for_test ();
        ret = Convert.to_integer(SCR.Execute(path(".target.bash"), cmd))
        if ret == 0
          @release_notes_filenames = Builtins.add(
            @release_notes_filenames,
            filename
          )
          Builtins.y2milestone("Successful")
          # At least one successfully installed -> internet test succeeded
          test_ret = true
        else
          Builtins.y2error("Downloading failed")
          @curl_ret_code = ret
        end
        # label of combobox where the log is selected
        menu_name = _("Download of Release Notes")
        # identify release notes by name of the product, bug 180581
        if Ops.get(Product.product_of_relnotes, url, "") != ""
          menu_name = Ops.add(
            menu_name,
            Builtins.sformat(
              " (%1)",
              Ops.get(Product.product_of_relnotes, url, "")
            )
          )
        end
        @logs = Builtins.add(
          @logs,
          menuname: menu_name, filename: log_filename
        )

        relnotes_counter += 1
      end
      test_ret
    end

    # Function checks two versions of installed rpm and decides whether the second one is
    # newer than the first one. This function ignores non-numerical values in versions
    #
    # @param installed_rpm_version [String] first version
    # @param downloaded_rpm_version [String] second version
    # @return [Boolean] true if the second one is newer than the first one
    def IsDownloadedVersionNewer(installed_rpm_version, downloaded_rpm_version)
      installed_rpm_version_l = Builtins.filter(
        Builtins.splitstring(installed_rpm_version, "-.")
      ) do |one_item|
        Builtins.regexpmatch(one_item, "^[0123456789]+$")
      end
      downloaded_rpm_version_l = Builtins.filter(
        Builtins.splitstring(downloaded_rpm_version, "-.")
      ) do |one_item|
        Builtins.regexpmatch(one_item, "^[0123456789]+$")
      end

      Builtins.y2milestone(
        "Evaluating installed %1 and downloaded %2 versions",
        installed_rpm_version_l,
        downloaded_rpm_version_l
      )

      installed_version_item = nil
      downloaded_version_item = nil

      downloaded_version_is_newer = false
      loop_counter = 0
      Builtins.foreach(installed_rpm_version_l) do |i_item|
        installed_version_item = Builtins.tointeger(i_item)
        downloaded_version_item = Builtins.tointeger(
          Ops.get(downloaded_rpm_version_l, loop_counter, "0")
        )
        if downloaded_version_item != installed_version_item
          downloaded_version_is_newer = Ops.greater_than(
            downloaded_version_item,
            installed_version_item
          )
          raise Break
        end
        loop_counter = Ops.add(loop_counter, 1)
      end

      Builtins.y2milestone(
        "%1 > %2 -> %3",
        downloaded_rpm_version,
        installed_rpm_version,
        downloaded_version_is_newer
      )
      downloaded_version_is_newer
    end

    # Function checks whether the downloaded and installed versions are different
    def IsDownloadedRPMInstallable(rpm_name, disk_file)
      query_format = "%{NAME}-%{VERSION}"

      # Checking the installed version of RPM
      cmd_installed_rpm_version = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "/bin/rpm -q --queryformat \"%1\" %2",
            query_format,
            rpm_name
          )
        )
      )
      if Ops.get_integer(cmd_installed_rpm_version, "exit", -1) != 0
        Builtins.y2warning(
          "Cannot check the installed RPM version: %1 -> %2",
          disk_file,
          cmd_installed_rpm_version
        )
        return true
      end
      installed_rpm_version = Ops.get_string(
        cmd_installed_rpm_version,
        "stdout",
        "undefined-i"
      )
      Builtins.y2milestone("Installed version: '%1'", installed_rpm_version)

      # Checking the downloaded version of RPM
      cmd_downloaded_rpm_version = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "/bin/rpm -qp --queryformat \"%1\" %2",
            query_format,
            disk_file
          )
        )
      )
      if Ops.get_integer(cmd_downloaded_rpm_version, "exit", -1) != 0
        Builtins.y2warning(
          "Cannot check the downloaded RPM version: %1 -> %2",
          disk_file,
          cmd_downloaded_rpm_version
        )
        return true
      end
      downloaded_rpm_version = Ops.get_string(
        cmd_downloaded_rpm_version,
        "stdout",
        "undefined-d"
      )
      Builtins.y2milestone("Downloaded version: '%1'", downloaded_rpm_version)

      # The same or older versions -> false
      IsDownloadedVersionNewer(installed_rpm_version, downloaded_rpm_version)
    end

    def install_release_notes
      test_ret = true

      Builtins.foreach(@release_notes_filenames) do |filename|
        ret1 = Pkg.RpmChecksig(filename)
        if !ret1
          Builtins.y2error("checksig of release notes failed")
          # popup error message
          Report.Error(
            _(
              "Cannot install downloaded release notes.\nRPM signature check failed."
            )
          )
          test_ret = false
          # next loop
          next
        end
        # Checking whether installed/new rpm versions are different (#164388)
        # Checking whether the downloaded one is newer (#167985)
        rpm_name = Ops.get(@release_notes_rpms, filename, "")
        if IsDownloadedRPMInstallable(rpm_name, filename)
          Builtins.y2milestone(
            "Downloaded version is newer, let's install it..."
          )
        else
          Builtins.y2milestone(
            "Downloaded version is the same or older, skipping..."
          )
          next
        end
        old2 = PackageCallbacks.EnableAsterixPackage(false)
        ret2 = Pkg.TargetInstall(filename)
        PackageCallbacks.EnableAsterixPackage(old2)
        if !ret2
          Builtins.y2error("installation release notes failed.")
          # popup error message
          Report.Error(_("Installation of downloaded release notes failed."))
          test_ret = false
          # next loop
          next
        end
      end

      test_ret
    end

    def handle_stage
      if @test_stage == :open # open connection
        if Mode.test
          mark_label(1, :arrow)
          @test_stage = :wait
          return
        end

        if !@already_up
          mark_label(1, :arrow)

          if !AskForPassword()
            Builtins.y2error("Password required")
            @test_stage = :finish
            @test_result = :failure
            mark_label(1, :dash)
            return
          end

          # start the connection
          Builtins.y2milestone("called Start")
          # label of combobox where the log is selected
          @logs = Builtins.add(
            @logs,
            menuname: _("Opening of Connection"),
            filename: "ifup.log",
            prio:     16
          )
          if !Internet.Start(Ops.add(@logdir, "/ifup.log"))
            # popup to inform user about the failure
            Report.Error(
              _(
                "Connecting to the Internet failed. View\nthe logs for details.\n"
              )
            )
            @test_stage = :finish
            @test_result = :failure
            mark_label(1, :dash)
            return
          end
        end
        @test_stage = :wait # not `copy. NM takes its time. #145153
        return
      end

      if @test_stage == :wait # wait until really connected
        if Mode.test
          @test_stage = :copy
          mark_label(1, :check)
          return
        end

        # status must be up
        if !Internet.Status
          # popup to inform user about the failure
          Report.Error(
            _(
              "Connecting to the Internet failed. View\nthe logs for details.\n"
            )
          )
          @test_stage = :finish
          @test_result = :failure
          mark_label(1, :dash) if !@already_up
          return
        end

        # and we must be connected
        if Internet.Connected
          Builtins.y2milestone("Connected ok")

          # even after we get an address, the test can fail. #145153
          # so before we have the dbus event filter, let's try this
          SCR.Execute(path(".target.bash"), "ip route list >&2")
          Builtins.y2milestone("Waiting 5000 to get initialized...")
          Builtins.sleep(5000)
          SCR.Execute(path(".target.bash"), "ip route list >&2")

          @test_stage = :copy
          mark_label(1, :check) if !@already_up
          return
        end

        # ping anything (www.suse.com) to trigger dod connections
        SCR.Execute(
          path(".target.bash_background"),
          "/bin/ping -c 1 -w 1 213.95.15.200"
        )
        return
      end

      if @test_stage == :copy # copy some status
        copy_logs1
        @test_stage = :relnotes
      end

      if @test_stage == :relnotes # download release notes
        mark_label(2, :arrow)

        ret = true

        # Product::relnotesurl_all=[ "http://www.suse.com/relnotes/i386/openSUSE/10.3/release-notes.rpm" ];
        # y2error("FAKE RELNOTES!");

        # #390738: need to read available products here (hopefully only one)
        # but need to switch off package callbacks first
        PackageCallbacks.RegisterEmptyProgressCallbacks
        Product.ReadProducts
        PackageCallbacks.RestorePreviousProgressCallbacks

        Builtins.y2milestone("Product::relnotesurl = %1", Product.relnotesurl)
        # Fallback for situation that mustn't exist
        if Builtins.size(Product.relnotesurl_all) == 0 &&
            (Product.relnotesurl.nil? || Product.relnotesurl == "")
          Popup.Warning(
            _(
              "No URL for the release notes defined. Internet test cannot be performed."
            )
          )
          ret = false
        elsif !download_release_notes
          # return code is not on the blacklist (meaning misconfigured network)
          # return true if user wants to continue despite the failure, false otherwise
          if !Builtins.contains(@curl_ret_codes_bad, @curl_ret_code)
            # popup informing user about the failure to retrieve release notes
            # most likely due to server-side error
            ret = Popup.ContinueCancel(
              _(
                "Download of latest release notes failed due to server-side error. \n" \
                  "This does not necessarily imply a faulty network configuration.\n" \
                  "\n" \
                  "Click 'Continue' to proceed to the next installation step. To skip any steps\n" \
                  "requiring an internet connection or to get back to your network configuration,\n" \
                  "click 'Cancel'.\n"
              )
            )
          else
            # popup to inform user about the failure
            Report.Error(
              _(
                "Download of latest release notes failed. View\nthe logs for details."
              )
            )
            ret = false
          end
          @test_stage = :close
        end
        if ret
          install_release_notes
          mark_label(2, :check)
        else
          @test_result = :failure
          mark_label(2, :dash)
        end

        # we don't check for patches anymore
        @test_stage = :close
        return
      end

      if @test_stage == :patches # check for updates
        if !Product.run_you
          @test_stage = :close
          return
        end

        mark_label(3, :arrow)

        cmd = "/usr/bin/online_update -q -V"
        # ugly hack (see bug #42177)
        # string cmd = "/bin/false";
        cmd = Ops.add(Ops.add(Ops.add(cmd, "> "), @logdir), "/you.log 2>&1")

        Builtins.y2milestone("online_update command: %1", cmd)

        SCR.Execute(
          path(".background.run"),
          cmd,
          "LANG" => GetLanguageUTF8()
        )
        ret = wait_for_test

        # label of combobox where the log is selected
        @logs = Builtins.add(
          @logs,
          menuname: _("Check for Patches"), filename: "you.log"
        )

        if ret == 0 || ret == 1 || ret == 2 # success
          @we_have_patches = ret != 0
          mark_label(3, :check)
        else
          # popup to inform user about the failure
          Report.Error(
            _("Check for latest updates failed. View\nthe logs for details.\n")
          )
          @test_result = :failure
          mark_label(3, :dash)
        end

        @test_stage = :close
        return
      end

      if @test_stage == :close # close connection
        if Mode.test
          mark_label(4, :arrow)
          @test_stage = :finish
          mark_label(4, :check)
          return
        end

        if !@already_up
          mark_label(4, :arrow)

          # Stop connection
          Builtins.y2milestone("Connection: stop")
          # label of combobox where the log is selected
          @logs = Builtins.add(
            @logs,
            menuname: _("Closing of Connection"),
            filename: "ifdown.log",
            prio:     14
          )
          if Internet.Stop(Ops.add(@logdir, "/ifdown.log"))
            mark_label(4, :check)
          else
            @test_result = :failure
            mark_label(4, :dash)
          end
        end

        @test_stage = :finish
        return
      end

      nil
    end
  end
end

Yast::InstDoNetTestClient.new.main
