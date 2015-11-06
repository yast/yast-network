require "yast/rake"

Yast::Tasks.submit_to :sle12sp1

Yast::Tasks.configuration do |conf|
  conf.obs_api = "https://api.suse.de/"
  conf.obs_target = "SLE-12-SP1"
  conf.obs_sr_project = "SUSE:SLE-12-SP1:GA"
  conf.obs_project = "Devel:YaST:Head"
  # lets ignore license check for now
  conf.skip_license_check << /.*/
end
