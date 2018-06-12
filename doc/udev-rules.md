Udev Rules in yast-network
==========================

<https://github.com/yast/yast-network>

What are Udev Rules
-------------------

If a computer has two network cards, how does it determine which one is
**eth0** and which one is **eth1**?

A Linux machine may have several network interfaces, such as eth0, eth1,
wlan0, enp0s3. These udev rules ensure the correct assignment of
interface names.

\_( "&lt;p&gt;&lt;b&gt;Udev Rules&lt;/b&gt; are rules for the kernel
device manager that allow\n" \ "associating the MAC address or BusID of
the network device with its name (for\n" \ "example, eth1, wlan0 ) and
assures a persistent device name upon reboot.\n" )

For a NIC a widget exists where you can change its name and choose
whether it will be pinned to its MAC (Ethernet address), or its PCI bus
address.

Why
---

The code of yast-network is messy, so Udev Rules is one area to clean it
up. It is simple enough and well defined.

Plan
----

-   \[x\] collect all mentions of "udev" in yast-network
-   \[ \] read them all and design a decent API
-   \[ \] cover the code with tests
-   \[ \] use the new API, possibly using old code underneath
-   \[ \] replace old implementation with a better one

AY interface
------------

The rnc schema says all elements are optional but the SLE12(also 15)
docs says name+rule+value are all required

<https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Network.names>

Semantics: the device **name** is identified by the field with the key
**rule** (sic!) having the value **value** (that does not allow some
complex identifications)

``` {.xml}
<networking>
  <net-udev config:type="list">
    <rule>
      <name>eth0</name>
      <rule>ATTR{address}</rule>
      <value>00:30:6E:08:FF:80</value>
    </rule>
  </net-udev>
</networking>
```

where is "udev" mentioned?
--------------------------

``` {.bash}
$ grep -r -H -i udev src | cut -d: -f1 | uniq -c | sort -n
      1 src/lib/network/install_inf_convertor.rb
      2 src/include/network/lan/complex.rb
      2 src/scrconf/cfg_udev_persistent.scr
      3 src/autoyast-rnc/networking.rnc
      3 src/modules/Lan.rb
      4 src/servers_non_y2/ag_udev_persistent
      5 src/clients/lan_auto.rb
     15 src/include/network/lan/hardware.rb
     18 src/lib/network/clients/save_network.rb
     19 src/lib/network/edit_nic_name.rb
     26 src/include/network/lan/udev.rb
     28 src/lib/network/network_autoyast.rb
    127 src/modules/LanItems.rb
```

Areas NOT in scope
------------------

These are related to Udev in the current code but let's not touch them
in this 1st stage.

### s390 rules (AY: networking/s390-devices)

are similar but not really

-   set up a virtual device
-   do not include a name(!?)

### driver rules (selecting the driver seems broken?)

the other part of ag~udevpersistent~ not part of AY?

API
---

### Naming

Anything named "udev" should be code-clean.

LanItems - keep it for now but remember that "item" is too generic yet
it combines info about a "nic" and its (stored) config.

"Udev" is an implementation detail, the upper layer should say
"NameRule"

"Udev name" -&gt; "device name", or "persistent device name"

In LanItems, keep the general interface of item\["udev"\]\["net"\] so
that existing code works, BUT instead of \["net"\] which is~a~
Array&lt;String&gt; make \["name~rule~"\] which is~a~ NameRule

### copying and identity

\#Items are deeply copied values? NO. GetLanItem and getCurrentItem
return the original data.

### LanItems item API

This is strictly speaking above our area of focus, but the current
naming is so awful that at least a glossary is needed to be able to
understand what's going on.

1.  current -&gt; Integer

    the **index** of the current item

2.  GetLanItem(item~id~) =&gt; item(item~id~) \# surprisingly no
    collisions with "item" lvar

3.  getCurrentItem =&gt; current~item~

4.  item~namerule~(item~id~) = item(item~id~)\["udev"\]\["name~rule~"\]

    also considering that \#item would be an adaptor object that would
    translate \#name~rule~ to \["udev"\]\["name~rule~"\] Does it need to
    exist? Nil? NullRule?

5.  current~itemnamerule~ = current~item~\["udev"\]\["name~rule~"\]

### target API

This is a sketch of the new API as emerging from the Usage section below

1.  NameRule

    1.  @udev \[UdevRule\]

    2.  \#matcher= and \#matcher(:bus~id~ or :mac)

    3.  \#value (case sensitive??)

    4.  \#name

        udev\["NAME"\]

2.  NameRules

    1.  \#pathname

        "/etc/udev/rules.d/70-persistent-net.rules"

### Usage

Here I list all the mentions of "udev" in the code and sketch out how to
write them better.

1.  InstallInfConvertor

    1.  AllowUdevModify

        checks if cmdline contains "biosdevname=..."

2.  NetworkLanComplexInclude src/include/network/lan/complex.rb

    1.  calls LanItems.update~itemudevrule~!(:bus~id~)

3.  Lan\#Export

    calls LanItems\#Export

4.  lan~auto~

    1.  ToAY converts the net-udev piece from a hash to an array

5.  NetworkLanHardwareInclude

    it's the Hardware tab device~name~ = LanItems.current~udevname~
    let's keep that

6.  save~network~

    \#copy~udevrules~

    s390 51\* leave that

    the rule file needs to be copied from inst-sys to target: need its
    fs path NameRules\#pathname (and use std ruby dirname+basename) BTW
    the <https://bugzilla.suse.com/show_bug.cgi?id=293366#c7> comment
    means a mkdir -p is fine

7.  edit~nicname~ EditNicName

    is a freshly rewritten class, yay 2013-09 mchf well, it is called
    like EditNicName.new.run and its \#initialize uses the ugly
    LanItemsApi so does \#run and \#CheckUdevNicName (sic)

    1.  to be removed:

        MAC~UDEVATTR~ = "ATTR{address}".freeze BUSID~UDEVATTR~ =
        "KERNELS".freeze

    2.  initialize

        @old_key = current~itemnamerule~.matcher

    3.  run

        LanItems.update~itemudevrule~!(udev~type~) (watch out, uses the
        ui symbol directly)

    4.  CheckUdevNicName

        uses LanItems\#GetCurrentName which is GetDeviceName(@current)
        ... and it never uses the "udev name" which confuses my naming
        plan :( renamed! to check~newdevicename~

8.  network~autoyast~

    renaming logic

    1.  create~udevs~

        "\# Creates udev rules according definition from profile" rename
        to create~namerulesfromprofile~ uses
        LanItems.createUdevFromIfaceName - well drop that, SLE10 compat
        calls assign~udevstodevs~

    2.  assign~udevstodevs~ (udev~rules~: Array&lt;AY~rule~&gt;)

        make nr = NameRule.from~ay~(hash(name rule value)) it's a
        standalone one not part of NameRules does an item match a
        NameRule

        rename~lanitem~

    3.  rename~lanitem~

        keep the signature because the renaming mess is fragile and
        we'll leave the logic unchanged for now

        LanItems.InitItemUdevRule(item~idx~) \# the only caller

9.  LanItems

    1.  \#current~udevname~

        deals with renaming, uses LanItems.GetItemUdev("NAME") -&gt;
        current~itemnamerule~.name def current~itemnamerule~;
        current~item~\["udev"\]\["name~rule~"\] + autovivify(?); end

    2.  LanItems\#update~itemudevrule~!(:mac or :bus~id~)

        implementation eventually does
        Items()[@current]\["udev"\]\["net"\] = new~rule~

        LanItems.current is the **index**, duh

        so: current~itemnamerule~.matcher = :bus~id~ \# maybe make/use
        an Enum class? but a symbol is ok

    3.  LanItems\#export

        should produce the net-udev part for Export

        export~s390devices~ export~netudev~ (warning, on s390 it
        constructs KERNELS rules detected from /sys probably keep the
        weird impl)

        NameRule\#to~ay~ -&gt; { "rule" =&gt; "KERNELS", "name" =&gt;
        "eth1", "value" =&gt; "0000:00:1f.6" } NameRules\#to~ay~ -&gt;
        an array of (NameRule\#to~ay~) (NOTE that LanItems\#export needs
        a \[name, rule\]...to~h~ conversion until the ToAY conversion is
        dropped)

    4.  createUdevFromIfaceName

        rename to name~rulesfromsle10names~ or just drop it quietly make
        implicitly defined rules via old style names
        ifcfg-eth-id-nn-nn-nn... ifcfg-eth-bus-nnnn-nn...

    5.  InitItemUdevRule

    6.  GetItemUdevRule(item~id~) -&gt; Array&lt;String&gt; rule

        Ops.get~list~(GetLanItem(itemId), \["udev", "net"\], \[\]) =&gt;
        item~namerule~(item~id~) -&gt; NameRule


