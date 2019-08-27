require "yast/rake"

Yast::Tasks.configuration do |conf|
  conf.skip_license_check << /doc\//
  conf.skip_license_check << /test\/data/
  conf.skip_license_check << /\.desktop$/
  conf.skip_license_check << /\.rnc$/
  # ensure we are not getting worse with documentation
  conf.documentation_minimal = 61 if conf.respond_to?(:documentation_minimal=)
end
