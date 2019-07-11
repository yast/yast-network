require "yast"

module Y2Network
  module Sequences
    # The responsibility of this class is to drive workflow for sequence of dialogs.
    #
    # In this case for interface allowed operations are add for adding new interface,
    # edit which edits existing device ( can exist only in memory ) and initialization
    # of s390 devices which needs specific activation before using it.
    # TODO: use UI::Sequence, but it needs also another object dialogs e.g for wifi
    class Interface
      include Yast::I18n
      include Yast::Logger

      def initialize
        Yast.include self, "network/lan/wizards.rb"
      end

      # Starts sequence for adding new interface and configuring it
      def add(default: nil)
        res = Y2Network::Dialogs::AddInterface.run(default: default)
        return unless res

        sym = edit(res)
        log.info "result of following edit #{sym.inspect}"
        sym = add(default: res.type) if sym == :back

        sym
      end

      # Starts sequence for editing configuration of interface
      def edit(builder)
        NetworkCardSequence("edit", builder: builder)
      end

      # Starts sequence for activating s390 device and configuring it
      def init_s390(builder)
        NetworkCardSequence("init_s390", builder: builder)
      end
    end
  end
end
