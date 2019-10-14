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
# File:  include/network/lan/cards.ycp
# Package:  Network configuration
# Summary:  Network cards database
# Authors:  Michal Svec <msvec@suse.cz>
#
#
# Originally copyied from yast1 NetCardDlg.cc.
#
# General syntax:
# $[ <type> : <list> ]
#
# <type> is the network device type name, for example:
#   "fddi", "tr", "arc", "ci", "hippi", "eth", "escon", "iucv", "ctc", "air"
#
# <list> contains maps in format:
#   "name"    <string>  user readable name of the card
#   "module"    <string>  kernel module name
#   "options"    <string>  kernel module options
#   "architecture"  <list>    allowed architectures:
#     "s390", "axp", "i386", "ix86", "x86_64", "ia64", "ppc", "sparc", ...
module Yast
  module NetworkLanCardsInclude
    def initialize_network_lan_cards(_include_target)
      textdomain "network"

      # Network cards database
      @NetworkCards = {
        "wlan"  => [
          {
            "module" => "airo_cs",
            # Network card name (wireless)
            "name"   => _(
              "Cisco/Aironet 802.11 wireless ISA/PCI and PCMCIA ethernet cards"
            )
          },
          {
            "module" => "orinoco",
            # Network card name (wireless)
            "name"   => _(
              "Lucent Orinoco, Prism II based, and similar wireless cards"
            )
          },
          {
            "module" => "orinoco_cs",
            # Network card name (wireless)
            "name"   => _(
              "PCMCIA Lucent Orinoco, Prism II based, and similar wireless cards"
            )
          },
          {
            "module" => "orinoco_pci",
            # Network card name (wireless)
            "name"   => _(
              "Wireless LAN cards using direct PCI interface"
            )
          },
          {
            "module" => "orinoco_plx",
            # Network card name (wireless)
            "name"   => _(
              "Wireless LAN cards using the PLX9052 PCI bridge"
            )
          },
          {
            "module" => "p80211",
            # Network card name (wireless)
            "name"   => _(
              "Wireless device using kernel module p80211.o"
            )
          },
          {
            "module" => "prism2_cs",
            # Network card name (wireless)
            "name"   => _(
              "Wireless device using kernel module prism2_cs.o"
            )
          },
          {
            "module" => "prism2_pci",
            # Network card name (wireless)
            "name"   => _(
              "Wireless device using kernel module prism2_pci.o"
            )
          },
          {
            "module" => "prism2_plx",
            # Network card name (wireless)
            "name"   => _(
              "Wireless device using kernel module prism2_plx.o"
            )
          },
          {
            "module" => "prism2_usb",
            # Network card name (wireless)
            "name"   => _(
              "Wireless device using kernel module prism2_usb.o"
            )
          }
        ],
        "eth"   => [
          # Network card name
          {
            "name"    => _("Apple onboard Ethernet mace"),
            "module"  => "mace",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _("Apple onboard Ethernet bmac"),
            "module"  => "bmac",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _("Apple onboard Ethernet gmac"),
            "module"  => "sungem",
            "options" => ""
          },
          {
            "name"    => "3Com 3c501",
            "module"  => "3c501",
            "options" => "io=0x280"
          },
          {
            "name"    => "3Com 3c503",
            "module"  => "3c503",
            "options" => "io=0x280"
          },
          {
            "name"    => "3Com 3c505",
            "module"  => "3c505",
            "options" => "io=0x300"
          },
          {
            "name"    => "3Com 3c507",
            "module"  => "3c507",
            "options" => "io=0x300"
          },
          {
            "name"    => "3Com 3c515",
            "module"  => "3c515",
            "options" => "options=0"
          },
          { "name" => "3Com 3c509/3c579", "module" => "3c509", "options" => "" },
          { "name" => "3Com 3c59x/3c90x", "module" => "3c59x", "options" => "" },
          # Network card name
          {
            "name"    => _("3Com 3c90x/3c980 B/C series"),
            "module"  => "3c90x",
            "options" => ""
          },
          {
            "name"    => "Adaptec Starfire",
            "module"  => "starfire",
            "options" => ""
          },
          {
            "name"    => "Alteon AceNIC/3C985/NetGear GA620",
            "module"  => "acenic",
            "options" => ""
          },
          {
            "name"    => "AMD LANCE and PCnet (AT1500/NE2100)",
            "module"  => "lance",
            "options" => ""
          },
          {
            "name"    => "AMD PCI PCnet32 (PCI bus NE2100)",
            "module"  => "pcnet32",
            "options" => ""
          },
          {
            "name"    => "Ansel Communications EISA 3200",
            "module"  => "ac3200",
            "options" => "io=0x300 irq=10 mem=0xd0000"
          },
          # Network card name
          {
            "name"    => _("Apricot Xen-II onboard ethernet"),
            "module"  => "apricot",
            "options" => "io=0x300"
          },
          # Network card name
          {
            "name"    => _("AT-LAN-TEC/RealTek pocket adapter"),
            "module"  => "atp",
            "options" => ""
          },
          { "name" => "AT1700", "module" => "at1700", "options" => "io=0x260" },
          {
            "name"    => "Cabletron E21xx",
            "module"  => "e2100",
            "options" => "io=0x300"
          },
          {
            "name"    => "Compaq Netelligent 10/100/NetFlex 3",
            "module"  => "tlan",
            "options" => ""
          },
          {
            "name"    => "Compex RL-100ATX",
            "module"  => "rl100a",
            "options" => ""
          },
          { "name" => "CS89x0", "module" => "cs89x0", "options" => "" },
          # Network card name
          {
            "name"    => _("D-Link DE600 pocket adapter"),
            "module"  => "de600",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _("D-Link DE620 pocket adapter"),
            "module"  => "de620",
            "options" => "io=0x378 irq=7 bnc=1"
          },
          {
            "name"    => "DE425, DE434, DE435, DE450, DE500",
            "module"  => "de4x5",
            "options" => "io=0x100"
          },
          {
            "name"    => "DECchip Tulip (dc21x4x) PCI",
            "module"  => "tulip",
            "options" => "options=0"
          },
          {
            "name"    => "DEPCA,DE10x,DE200,DE201,DE202,DE422",
            "module"  => "depca",
            "options" => "io=0x200"
          },
          {
            "name"    => "Digi Intl. RightSwitch SE-X",
            "module"  => "dgrs",
            "options" => ""
          },
          {
            "name"    => "DM9102 PCI Fast Ethernet",
            "module"  => "dmfe",
            "options" => ""
          },
          {
            "name"    => "EtherWORKS 3 (DE203, DE204, DE205)",
            "module"  => "ewrk3",
            "options" => "io=0x300"
          },
          {
            "name"    => "FMV-181/182/183/184",
            "module"  => "fmv18x",
            "options" => "io=0x220"
          },
          {
            "name"    => "SysKonnect Gigabit Ethernet 984x",
            "module"  => "sk98lin",
            "options" => ""
          },
          {
            "name"    => "HP 10/100VG PCLAN (ISA, EISA, PCI)",
            "module"  => "hp100",
            "options" => "hp100_port=0x380"
          },
          {
            "name"    => "HP PCLAN+ (27247B and 27252A)",
            "module"  => "hp-plus",
            "options" => "io=0x300"
          },
          {
            "name"    => "HP PCLAN (27245 / 27xxx)",
            "module"  => "hp",
            "options" => "io=0x300"
          },
          { "name" => "IBM OSA LCS", "module" => "lcs", "options" => "" },
          # Network card name
          {
            "name"    => _("ICL EtherTeam 16i/32 (experimental)"),
            "module"  => "eth16i",
            "options" => "io=0x2a0"
          },
          {
            "name"    => "Intel EtherExpress 16",
            "module"  => "eexpress",
            "options" => "io=0x300"
          },
          {
            "name"    => "Intel EtherExpress Pro",
            "module"  => "eepro",
            "options" => "io=0x260"
          },
          {
            "name"    => "Intel EtherExpress Pro 100",
            "module"  => "eepro100",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _(
              "Intel PRO/100 / EtherExpress PRO/100 (alternate driver)"
            ),
            "module"  => "e100",
            "options" => ""
          },
          { "name" => "Intel PRO/1000", "module" => "e1000", "options" => "" },
          {
            "name"    => "Mylex EISA LNE390A/B",
            "module"  => "lne390",
            "options" => ""
          },
          {
            "name"    => "NE 2000 / NE 1000 (ISA)",
            "module"  => "ne",
            "options" => "io=0x300"
          },
          { "name" => "NE 2000 (PCI)", "module" => "ne2k-pci", "options" => "" },
          { "name" => "Netgear FA 311", "module" => "natsemi", "options" => "" },
          {
            "name"    => "NI5210",
            "module"  => "ni52",
            "options" => "io=0x360 irq=9 memstart=0xd0000 memend=0xd4000"
          },
          { "name" => "NI5010", "module" => "ni5010", "options" => "" },
          {
            "name"    => "NI6510 (am7990 \"lance\" chip)",
            "module"  => "ni65",
            "options" => "io=0x360 irq=9 dma=0"
          },
          {
            "name"    => "Novell/Eagle/Microdyne NE3210 EISA",
            "module"  => "ne3210",
            "options" => ""
          },
          {
            "name"    => "OSA Express Gigabit Ethernet",
            "module"  => "qeth",
            "options" => ""
          },
          {
            "name"    => "Packet Engines Yellowfin Gigabit",
            "module"  => "yellowfin",
            "options" => ""
          },
          # $["name" : "PCMCIA",
          #   "module" : "off",
          #   "options" : "",
          # ],
          {
            "name"    => "Racal-Interlan EISA ES3210",
            "module"  => "es3210",
            "options" => ""
          },
          {
            "name"    => "RealTek RTL8129/8139",
            "module"  => "rtl8139",
            "options" => ""
          },
          # # 48973
          {
            "name"    => "SGI IO9/IO10 Gigabit Ethernet (Copper)",
            "module"  => "tg3",
            "options" => ""
          },
          {
            "name"    => "SiS 900 PCI Fast Ethernet",
            "module"  => "sis900",
            "options" => ""
          },
          {
            "name"    => "SMC 83c170 EPIC/100",
            "module"  => "epic100",
            "options" => ""
          },
          {
            "name"    => "SMC 9194",
            "module"  => "smc9194",
            "options" => "io=0x200"
          },
          {
            "name"    => "SMC Ultra",
            "module"  => "smc-ultra",
            "options" => "io=0x200"
          },
          {
            "name"    => "SMC Ultra 32",
            "module"  => "smc-ultra32",
            "options" => ""
          },
          {
            "name"    => "Sun BigMAC 10/100baseT",
            "module"  => "sunbmac",
            "options" => ""
          },
          {
            "name"    => "Sun Happy Meal 10/100baseT",
            "module"  => "sunhme",
            "options" => ""
          },
          {
            "name"    => "Sun MyriCOM Gigabit Ethernet",
            "module"  => "myri_sbus",
            "options" => ""
          },
          { "name" => "Sun QuadEthernet", "module" => "sunqe", "options" => "" },
          {
            "name"    => "VIA VT86c100A Rhine-II",
            "module"  => "via-rhine",
            "options" => ""
          },
          {
            "name"    => "Western Digital WD80x3",
            "module"  => "wd",
            "options" => ""
          }
        ],
        "veth"  => [
          # Network card name
          {
            "name"    => _("iSeries Virtual Network"),
            "module"  => "veth",
            "options" => ""
          }
        ],
        "tr"    => [
          # Network card name
          {
            "name"    => _("IBM Tropic chipset token ring"),
            "module"  => "ibmtr",
            "options" => "io=0xa20"
          },
          # Network card name
          {
            "name"    => _("IBM Olympic chipset PCI Token Ring"),
            "module"  => "olympic",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _("IBM OSA Token Ring"),
            "module"  => "lcs",
            "options" => ""
          },
          {
            "name"    => "SysKonnect Token Ring",
            "module"  => "sktr",
            "options" => ""
          }
        ],
        "arc"   => [
          # Network card name
          {
            "name"    => _("ARCnet COM90xx (standard)"),
            "module"  => "com90xx",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _("ARCnet COM90xx (in IO-mapped mode)"),
            "module"  => "com90io",
            "options" => ""
          },
          { "name" => "ARCnet RIM I", "module" => "arcrimi", "options" => "" },
          {
            "name"    => "ARCnet COM20020",
            "module"  => "com20020",
            "options" => ""
          },
          {
            "name"    => "ARCnet COM20020 (ISA)",
            "module"  => "com20020-isa",
            "options" => ""
          },
          {
            "name"    => "ARCnet COM20020 (PCI)",
            "module"  => "com20020-pci",
            "options" => ""
          }
        ],
        "air"   => [
          {
            "name"    => "Airport",
            "module"  => "airport",
            "options" => "network_name="
          }
        ],
        "fddi"  => [
          # Network card name
          {
            "name"    => _("Digital Equipment Corporation FDDI controller"),
            "module"  => "defxx",
            "options" => ""
          },
          # Network card name
          {
            "name"    => _(
              "SysKonnect FDDI adapter (SK-55xx, SK-58xx, Netelligent 100)"
            ),
            "module"  => "skfp",
            "options" => ""
          }
        ],
        "hippi" => [
          {
            "name"    => "Essential RoadRunner HIPPI",
            "module"  => "rrunner",
            "options" => ""
          }
        ],
        "ctc"   => [
          # Network subsystem name
          {
            "name"    => _("Channel-to-Channel (CTC) network"),
            "module"  => "ctc",
            "options" => ""
          }
        ],
        "hsi"   => [
          # Network subsystem name
          {
            "name"    => _("Hipersockets (HSI) Network"),
            "module"  => "qeth",
            "options" => ""
          }
        ],
        "lcs"   => [
          # Network subsystem name
          { "name" => _("IBM OSA LCS"), "module" => "lcs", "options" => "" }
        ],
        "escon" => [
          # Network subsystem name
          {
            "name"    => _("Enterprise System Connector (ESCON) network"),
            "module"  => "ctc",
            "options" => ""
          }
        ],
        "ficon" => [
          # Network subsystem name
          {
            "name"    => _("Fiberchannel System Connector (FICON) Network"),
            "module"  => "ctc",
            "options" => ""
          }
        ],
        "iucv"  => [
          # Network subsystem name
          {
            "name"    => _("Inter User Communication Vehicle (IUCV)"),
            "module"  => "netiucv",
            "options" => ""
          }
        ],
        "ci"    => [
          # Network card name
          {
            "name"    => _("CI7000 adapter"),
            "module"  => "c7000",
            "options" => ""
          }
        ]
      }

      # EOF
    end
  end
end
