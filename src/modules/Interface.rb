module Y2Network
  class Interface
    # @return [String] interface name
    attr_accessor :name

    def initialize(name: )
      @name = name
    end
  end
end
