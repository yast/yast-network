require "yast"

module Y2Network
  module Sequences
    # Sequence for interface
    # TODO: use UI::Sequence, but it needs also another object dialogs e.g for wifi
    class Interface
      def initialize
        Yast.include self, "network/lan/wizards.rb"
      end

      def add
      end

      def edit(builder)
        
      end

      def init_s390(builder)
      end
    end
  end
end
