# encoding: utf-8

# File:        include/network/lan/s390.ycp
# Package:     Network configuration
# Summary:     Network card adresss configuration dialogs
# Authors:     Michal Filka <mfilka@suse.cz>
#
# Functions for accessing and handling s390 specific needs.
module Yast
  module NetworkLanS390Include
    SYS_DIR = "/sys/class/net".freeze

    def initialize_network_lan_s390(_include_target)
      Yast.import "FileUtils"
    end

    # Checks if driver was successfully loaded for particular device.
    def s390_DriverLoaded(devname)
      return false if !Arch.s390
      return false if devname.empty?

      FileUtils.IsDirectory("#{SYS_DIR}/#{devname}") == true
    end

    # Reads particular qeth attribute and returns its value as a string.
    #
    # @param [String] attrib attribute name as exported by qeth module
    # @return attribute value or nil in case of error.
    def s390_ReadQethAttribute(devname, attrib)
      return nil if !s390_DriverLoaded(devname)

      result = Convert.to_string(
        SCR.Read(
          path(".target.string"),
          Builtins.sformat("%1/%2/device/%3", SYS_DIR, devname, attrib)
        )
      )

      Builtins.regexpsub(result, "(.*)\n", "\\1")
    end

    # Reads attributes for particular qeth based network device.
    #
    # Returned map is compatible with similar map used for storing sysconfig values used elswhere in the code.
    # As a consequence, boolean values are stored as strings with yes/no value.
    #
    # Currently loaded attributes are:
    # QETH_LAYER2      yes/no string.
    # QETH_PORTNAME    portname or empty string
    # QETH_PORTNUMBER  portnumber or empty string
    # QETH_CHANIDS     read/write/control channel ids separated by space (compatibility requirement)
    #
    # see lsqeth for inspiration
    #
    # @return a map with keys QETH_LAYER2, QETH_PORTNAME, QETH_PORTNUMBER, QETH_CHANIDS
    def s390_ReadQethConfig(devname)
      return {} if devname.empty?
      return {} if !s390_DriverLoaded(devname)

      result = {}

      qeth_layer2 = s390_ReadQethAttribute(devname, "layer2") == "1" ? "yes" : "no"
      result = Builtins.add(result, "QETH_LAYER2", qeth_layer2)

      qeth_portname = s390_ReadQethAttribute(devname, "portname")
      result = Builtins.add(result, "QETH_PORTNAME", qeth_portname)

      qeth_portno = s390_ReadQethAttribute(devname, "portno")
      result = Builtins.add(result, "QETH_PORTNUMBER", qeth_portno)

      # FIXME: another code handles chanids merged in one string separated by spaces.
      read_chan = s390_ReadQethAttribute(devname, "cdev0")
      write_chan = s390_ReadQethAttribute(devname, "cdev1")
      ctrl_chan = s390_ReadQethAttribute(devname, "cdev2")
      qeth_chanids = Builtins.mergestring(
        [read_chan, write_chan, ctrl_chan],
        " "
      )
      result = Builtins.add(result, "QETH_CHANIDS", qeth_chanids)

      # TODO: ipa_takover. study a bit. It cannot be read from /sys. Not visible using lsqeth,
      # qethconf configures it.

      Builtins.y2debug("s390_ReadQethConfig: %1", result)

      deep_copy(result)
    end
  end
end
