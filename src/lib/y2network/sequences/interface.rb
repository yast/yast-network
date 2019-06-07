require "yast"

module Y2Network
  module Sequences
    # Sequence for interface
    # TODO: use UI::Sequence, but it needs also another object dialogs e.g for wifi
    class Interface
      include Yast::I18n

      def initialize
        Yast.include self, "network/lan/wizards.rb"
      end

      def add
        res = Y2Network::Dialogs::AddInterface.run
        return unless res

        edit(res)
      end

      def edit(builder)
        NetworkCardSequence("edit", builder: builder)
      end

      def init_s390(builder)
        NetworkCardSequence("init_s390", builder: builder)
      end
    end
  end
end
