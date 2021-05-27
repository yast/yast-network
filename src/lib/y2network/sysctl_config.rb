require "cfa/sysctl_config"

module Y2Network
  class SysctlConfig < CFA::SysctlConfig
    def present?(attr)
      files.any? { |f| f.present?(attr) }
    end
  end
end
