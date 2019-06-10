require "yast"

module Y2Network
  module Sequences
    # Sequence for interface
    # TODO: use UI::Sequence, but it needs also another object dialogs e.g for wifi
    class Interface
      include Yast::I18n
      include Yast::Logger

      def initialize
        Yast.include self, "network/lan/wizards.rb"
      end

      def add(default: nil)
        res = Y2Network::Dialogs::AddInterface.run(default: default)
        return unless res

        sym = edit(res)
        log.info "result of following edit #{sym.inspect}"
        sym = add(default: res.type) if sym == :back

        sym
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
