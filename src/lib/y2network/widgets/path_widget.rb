require "abstract_method"

module Y2Network
  module Widgets
    # Generic widget for path with browse button
    # TODO: add to CWM as generic widget
    class PathWidget < CWM::CustomWidget
      def initialize
        textdomain "network"
      end

      abstract_method :label
      abstract_method :browse_label

      def contents
        HBox(
          InputField(Id(text_id), label),
          PushButton(Id(button_id), button_label)
        )
      end

      def handle
        directory = File.dirname(value)
        file = ask_method(directory)
        self.value = file if file

        nil
      end

      def value
        Yast::UI.QueryWidget(Id(text_id), :Value)
      end

      def value=(path)
        Yast::UI.ChangeWidget(Id(text_id), :Value, path)
      end

      def text_id
        widget_id + "_path"
      end

      def button_id
        widget_id + "_browse"
      end

      def button_label
        "..."
      end

      # UI method responsible for asking for file/directory. By default uses
      # Yast::UI.AskForExistingFile with "*" filter. Redefine if different popup is needed or
      # specific filter required.
      def ask_method(directory)
        Yast::UI.AskForExistingFile(directory, "*", browse_label)
      end
    end
  end
end
