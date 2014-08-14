# A factory for the elements contained in SCR.Read(path(".probe.netcard"))
# @return one item for a .probe.netcard list
def probe_netcard_factory(num)
  num = num.to_s
  dev_name = "eth#{num}"

  {
    "bus"           => "Virtio",
    "class_id"      => 2,
    "dev_name"      => dev_name,
    "dev_names"     => [dev_name],
    "device"        => "Ethernet Card #{num}",
    "device_id"     => 262145,
    "driver"        => "virtio_net",
    "driver_module" => "virtio_net",
    "drivers"       => [
                        {
                          "active"   => true,
                          "modprobe" => true,
                          "modules"  => [["virtio_net", ""]]
                        }
                       ],
    "modalias"      => "virtio:d00000001v00001AF4",
    "model"         => "Virtio Ethernet Card #{num}",
    "resource"      => {
      "hwaddr" => [ {"addr"  => "52:54:00:5b:b2:7#{num}"} ],
      "link"=>    [ {"state" => true} ]
    },
    "sub_class_id"  => 0,
    "sysfs_bus_id"  => "virtio#{num}",
    "sysfs_id"      => "/devices/pci0000:00/0000:00:03.0/virtio#{num}",
    "unique_key"    => "vWuh.VIRhsc57kT#{num}",
    "vendor"        => "Virtio",
    "vendor_id"     => 286740
  }
end
