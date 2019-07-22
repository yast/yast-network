require "yast/rake"

Yast::Tasks.configuration do |conf|
  # lets ignore license check for now
  conf.skip_license_check << /.*/
  # ensure we are not getting worse with documentation
  conf.documentation_minimal = 62 if conf.respond_to?(:documentation_minimal=)
end
