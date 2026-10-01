require "opal"

module Cradare2
  module Util
    # Centralized CLI formatting helper leveraging Opal's one-shot component print mode.
    # Provides styled tables, boxes, rules, badges, syntax-highlighted code views,
    # and rendered markdown for rich terminal diagnostics while respecting NO_COLOR and non-TTY modes.
    module CLIFormatter
      extend self

      # Renders a bordered container box around text content.
      def box(
        text : String,
        title : String? = nil,
        border : Symbol | Opal::Border | String = :rounded,
        border_fg : Opal::Color | Symbol | String = Opal::Color.none,
        padding : Int32 = 1,
        width : Int32? = nil,
        color : Bool? = nil,
      ) : String
        Opal::UI::Box.to_string(
          text: text,
          title: title,
          border: border,
          border_fg: border_fg,
          padding: padding,
          width: width,
          color: color
        )
      end

      # Renders a formatted data table with headers, rows, and optional zebra striping.
      def table(
        headers : Array(String),
        rows : Array(Array(String)),
        width : Int32? = nil,
        zebra : Bool = false,
        border_style : Opal::Border | Symbol | String | Nil = :rounded,
        color : Bool? = nil,
      ) : String
        Opal::UI::Table.to_string(
          headers: headers,
          rows: rows,
          width: width,
          zebra: zebra,
          border_style: border_style,
          color: color
        )
      end

      # Renders a horizontal divider rule with centered label text.
      def rule(
        text : String? = nil,
        char : Char = '─',
        fg : Opal::Color | Symbol | String = Opal::Color.none,
        align : Symbol = :center,
        width : Int32? = nil,
        color : Bool? = nil,
      ) : String
        Opal::UI::Rule.to_string(
          text: text,
          char: char,
          fg: fg,
          align: align,
          width: width,
          color: color
        )
      end

      # Renders a pill badge with custom background and foreground colors.
      def badge(
        label : String,
        bg : Opal::Color | Symbol | String = :blue,
        fg : Opal::Color | Symbol | String = :white,
        bold : Bool = true,
        color : Bool? = nil,
      ) : String
        Opal::UI::Badge.to_string(
          label: label,
          bg: bg,
          fg: fg,
          bold: bold,
          color: color
        )
      end

      # Renders syntax-highlighted source code with optional line numbers.
      def code(
        source : String,
        language : Symbol | String = :crystal,
        show_line_numbers : Bool = true,
        start_line : Int32 = 1,
        width : Int32? = nil,
        color : Bool? = nil,
      ) : String
        Opal::UI::CodeView.to_string(
          code: source,
          language: language,
          show_line_numbers: show_line_numbers,
          start_line: start_line,
          width: width,
          color: color
        )
      end

      # Renders GitHub-flavored Markdown text directly into an ANSI-formatted string.
      def markdown(text : String, width : Int32? = nil) : String
        w = width || (Opal::Terminal::Info.new.width rescue 80)
        Opal.render_markdown(text, width: w)
      end
    end
  end
end
