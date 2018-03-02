require "y2storage"
require "network/install_inf_convertor"
require "network/network_autoconfiguration"
require "network/network_autoyast"

module Yast
  class SaveNetworkClient < Client
    include Logger

    def main
      textdomain "network"

      Yast.import "DNS"
      Yast.import "FileUtils"
      Yast.import "NetworkStorage"
      Yast.import "Installation"
      Yast.import "String"
      Yast.import "Mode"
      Yast.import "Arch"

      Yast.include self, "network/routines.rb"
      Yast.include self, "network/complex.rb"

      # for update system don't copy network from inst_sys (#325738)
      if !Mode.update
        save_network
      else
        Builtins.y2milestone("update - skip save_network")
      end

      nil
    end

  private

    def adjust_for_network_disks(file)
      # storage-ng
      # Check if installation is targeted to a remote destination.
      devicegraph = Y2Storage::StorageManager.instance.staging
      is_disk_in_network = devicegraph.filesystem_in_network?(
        Installation.destdir
      )

      if !is_disk_in_network
        log.info("Directory \"#{Installation.destdir}\" is not on a network based device")
        return
      end

      log.info("Directory \"#{Installation.destdir}\" is on a network based device")

      # tune ifcfg file for remote filesystem
      SCR.Execute(
        path(".target.bash"),
        "sed -i s/^[[:space:]]*STARTMODE=.*/STARTMODE='nfsroot'/ #{file}"
      )
    end

    ETC = "/etc/".freeze
    SYSCONFIG = "/etc/sysconfig/network/".freeze

    def CopyConfiguredNetworkFiles
      return if Mode.autoinst && !NetworkAutoYast.instance.keep_net_config?

      log.info(
        "Copy network configuration files from 1st stage into installed system"
      )

      inst_dir = Installation.destdir

      copy_receipts = [
        { dir: SYSCONFIG, file: "ifcfg-*" },
        { dir: SYSCONFIG, file: "ifroute-*" },
        { dir: SYSCONFIG, file: "routes" },
        { dir: ETC + "wicked/", file: "common.xml" },
        { dir: ETC, file: DNSClass::HOSTNAME_FILE }
      ]

      # just copy files
      copy_receipts.each do |receipt|
        file = receipt[:dir] + receipt[:file]
        adjust_for_network_disks(file) if file.include?("ifcfg-")

        copy_from = String.Quote(file)
        copy_to = String.Quote(inst_dir + receipt[:dir])

        log.info("Copying #{copy_from} to #{copy_to}")

        cmd = "cp " << copy_from << " " << copy_to
        ret = SCR.Execute(path(".target.bash_output"), cmd)

        log.warn("cmd: '#{cmd}' failed: #{ret}") if ret["exit"] != 0
      end

      copy_to = String.Quote(inst_dir + SYSCONFIG)

      # merge files with default installed by sysconfig
      ["dhcp", "config"].each do |file|
        source_file = SYSCONFIG + file
        dest_file = copy_to + file
        # apply options from initrd configuration files into installed system
        # i.e. just modify (not replace) files from sysconfig rpm
        # FIXME: this must be ripped out, refactored and tested
        # In particular, values containing slashes will break the last sed
        command = "\n" \
          "source_file=#{source_file};dest_file=#{dest_file}\n" \
          "grep -v \"^[[:space:]]*#\" $source_file | grep = | while read option\n" \
          " do\n" \
          "  key=${option%=*}=\n" \
          "  grep -v \"^[[:space:]]*#\" $dest_file | grep -q $key\n" \
          "  if [ $? != \"0\" ]\n" \
          "   then\n" \
          "    echo \"$option\" >> $dest_file\n" \
          "   else\n" \
          "    sed -i s/\"^[[:space:]]*$key.*\"/\"$option\"/g $dest_file\n" \
          "  fi\n" \
          " done"
        ret = SCR.Execute(path(".target.bash_output"), command)

        log.error("Execute file merging script failed: #{ret}") if ret["exit"] != 0
      end
      # FIXME: proxy

      nil
    end

    def copy_udev_rules
      dest_root = String.Quote(Installation.destdir)

      if Arch.s390
        log.info("Copy S390 specific udev rule files (/etc/udev/rules/51*)")

        WFM.Execute(
          path(".local.bash"),
          Builtins.sformat(
            "/bin/cp -p %1/51-* '%2%1'",
            "/etc/udev/rules.d",
            dest_root
          )
        )
      end

      # Deleting lockfiles and re-triggering udev events for *net is not needed any more
      # (#292375 c#18)

      udev_rules_srcdir = "/etc/udev/rules.d"
      net_srcfile = "70-persistent-net.rules"

      udev_rules_destdir = dest_root + udev_rules_srcdir
      net_destfile = dest_root + udev_rules_srcdir + "/" + net_srcfile

      log.info("udev_rules_destdir #{udev_rules_destdir}")
      log.info("net_destfile #{net_destfile}")

      # Do not create udev_rules_destdir if it already exists (in case of update)
      # (bug #293366, c#7)

      if !FileUtils.Exists(udev_rules_destdir)
        log.info("#{udev_rules_destdir} does not exist yet, creating it")
        WFM.Execute(
          path(".local.bash"),
          "mkdir -p '#{udev_rules_destdir}'"
        )
      else
        log.info("File #{udev_rules_destdir} exists")
      end

      if !Mode.update
        log.info("Copying #{net_srcfile} to the installed system ")
        WFM.Execute(
          path(".local.bash"),
          "/bin/cp -p '#{udev_rules_srcdir}/#{net_srcfile}' '#{net_destfile}'"
        )
      else
        log.info("Not copying file #{net_destfile} - update mode")
      end

      nil
    end

    # Copies parts configuration created during installation.
    #
    # Copies several config files which should be preserved when installation
    # is done. E.g. ifcfg-* files, custom udev rules and so on.
    def copy_from_instsys
      # skip from chroot
      old_SCR = WFM.SCRGetDefault
      new_SCR = WFM.SCROpen("chroot=/:scr", false)
      WFM.SCRSetDefault(new_SCR)

      # this has to be done here (out of chroot) bcs:
      # 1) udev agent doesn't support SetRoot
      # 2) original ifcfg file is copied otherwise too. It doesn't break things itself
      # but definitely not looking well ;-)
      NetworkAutoYast.instance.create_udevs if Mode.autoinst

      copy_dhcp_info
      copy_udev_rules
      CopyConfiguredNetworkFiles()

      # close and chroot back
      WFM.SCRSetDefault(old_SCR)
      WFM.SCRClose(new_SCR)

      nil
    end

    WICKED_DHCP_PATH = "/var/lib/wicked/".freeze
    WICKED_DHCP_FILES = ["duid.xml", "iaid.xml", "lease*.xml"].freeze
    DHCP_CLIENT_PATH = "/var/lib/dhcpcd/".freeze
    DHCP_CLIENT_CACHE = "dhcpcd-*.cache".freeze
    DHCPv6_CLIENT_CACHE_PATH = "/var/lib/dhcpv6".freeze

    def copy_dhcp_info
      # Ensure directories exist
      wicked_dest_dir = Installation.destdir + WICKED_DHCP_PATH
      dhcpcd_dest_dir = Installation.destdir + DHCP_CLIENT_PATH
      dhcpv6_dest = Installation.destdir + DHCPv6_CLIENT_CACHE_PATH

      # Copy wicked dhcp files
      ::FileUtils.mkdir_p(wicked_dest_dir)
      wicked_files = WICKED_DHCP_FILES.map { |f| WICKED_DHCP_PATH + f }
      ::FileUtils.cp(::Dir.glob(wicked_files), wicked_dest_dir, preserve: true)

      # Copy DHCP client cache so that we can request the same IP (#43974).
      ::FileUtils.mkdir_p(dhcpcd_dest_dir)
      dhcp_client_files = ::Dir.glob(DHCP_CLIENT_PATH + DHCP_CLIENT_CACHE)
      ::FileUtils.cp(dhcp_client_files, dhcpcd_dest_dir, preserve: true)

      # Copy DHCPv6 (DHCP for IPv6) client cache.
      ::FileUtils.cp(DHCPv6_CLIENT_CACHE_PATH, dhcpv6_dest, preserve: true)
    end

    # Creates target's default DNS configuration
    #
    # It proposes a predefined default values in common installation, exits
    # in AY mode.
    def configure_dns
      return if Mode.autoinst

      NetworkAutoconfiguration.instance.configure_dns

      DNS.create_hostname_link
    end

    # Creates target's /etc/hosts configuration
    #
    # It uses hosts' configuration as defined in AY profile (if any) or
    # proceedes according the proposal
    def configure_hosts
      configured = false
      configured = NetworkAutoYast.instance.configure_hosts if Mode.autoinst
      NetworkAutoconfiguration.instance.configure_hosts if !configured
    end

    # Invokes configuration according automatic proposals or AY profile
    #
    # It creates a proposal in case of common installation. In case of AY
    # installation it does full import of <networking> section
    def configure_lan
      NetworkAutoconfiguration.instance.configure_virtuals

      if !Mode.autoinst
        configure_dns
      else
        NetworkAutoYast.instance.configure_lan
      end

      # this depends on DNS configuration
      configure_hosts
    end

    # It does an automatic configuration of installed system
    #
    # Basically, it runs several proposals.
    def configure_target
      # creates target's network configuration
      configure_lan

      # set proper network service
      set_network_service

      SCR.Execute(path(".target.bash"), "chkconfig network on")

      # if portmap running - start it after reboot
      WFM.Execute(
        path(".local.bash"),
        "pidofproc rpcbind && touch /var/lib/YaST2/network_install_rpcbind"
      )

      nil
    end

    # Sets default network service
    def set_network_service
      if Mode.autoinst
        NetworkAutoYast.instance.set_network_service
        return
      end

      log.info("Setting network service according to product preferences")

      if Lan.UseNetworkManager
        log.info("- using NetworkManager")
        NetworkService.use_network_manager
      else
        log.info("- using wicked")
        NetworkService.use_wicked
      end

      NetworkService.EnableDisableNow
    end

    # this replaces bash script create_interface
    def save_network
      log.info("starting save_network")

      copy_from_instsys
      configure_target

      nil
    end
  end
end
