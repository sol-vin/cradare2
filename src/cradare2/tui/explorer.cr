require "opal"
require "../client"
require "../models/function"
require "../models/section"
require "../models/security_info"

module Cradare2
  module TUI
    # Interactive terminal binary explorer and decompiler model powered by Opal TEA.
    class ExplorerModel
      include Opal::TEA::Model

      getter client : Client
      getter functions : Array(Model::Function)
      getter filtered_functions : Array(Model::Function)
      getter selected_func_idx : Int32 = 0
      getter active_tab : Int32 = 0      # 0: Code, 1: Sections, 2: Security
      getter focus_pane : Symbol = :list # :list or :code
      getter? side_by_side : Bool = true
      getter? show_asm : Bool = true
      getter search_query : String = ""
      getter? searching : Bool = false
      getter code_scroll : Int32 = 0

      @decomp_cache = {} of UInt64 => String
      @disasm_cache = {} of UInt64 => String

      def initialize(@client : Client)
        @functions = @client.functions
        @filtered_functions = @functions.dup
      end

      def self.run(client : Client) : Nil
        model = new(client)
        prog = Opal::TEA::Program.new(model, alt_screen: true, mouse_enabled: false)
        prog.run
      end

      def init : Opal::TEA::Cmd
        Opal::TEA::Cmd.none
      end

      property width : Int32 = 100
      property height : Int32 = 30

      def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
        case msg
        when Opal::TEA::WindowSizeMsg
          @width = msg.width
          @height = msg.height
          {self, Opal::TEA::Cmd.none}
        when Opal::TEA::KeyMsg
          handle_key(msg)
        else
          {self, Opal::TEA::Cmd.none}
        end
      end

      def view : String
        view(@width, @height)
      end

      private def handle_key(key : Opal::TEA::KeyMsg) : {Opal::TEA::Model, Opal::TEA::Cmd}
        k = key.key.downcase

        if @searching
          case k
          when "enter", "escape"
            @searching = false
          when "backspace"
            @search_query = @search_query[0...-1]? || ""
            apply_filter
          else
            if key.key.size == 1
              @search_query += key.key
              apply_filter
            end
          end
          return {self, Opal::TEA::Cmd.none}
        end

        case k
        when "q", "ctrl+c"
          return {self, Opal::TEA::Cmd.quit}
        when "tab"
          @focus_pane = (@focus_pane == :list ? :code : :list)
        when "1"
          @active_tab = 0
        when "2"
          @active_tab = 1
        when "3"
          @active_tab = 2
        when "s"
          @side_by_side = !@side_by_side
        when "a"
          @show_asm = true
        when "c"
          @show_asm = false
        when "/"
          @searching = true
          @search_query = ""
        when "escape", "esc"
          @search_query = ""
          apply_filter
        when "j", "down"
          if @focus_pane == :list
            @selected_func_idx = Math.min(@filtered_functions.size - 1, @selected_func_idx + 1)
            @code_scroll = 0
          else
            @code_scroll += 1
          end
        when "k", "up"
          if @focus_pane == :list
            @selected_func_idx = Math.max(0, @selected_func_idx - 1)
            @code_scroll = 0
          else
            @code_scroll = Math.max(0, @code_scroll - 1)
          end
        when "page_up", "pageup"
          if @focus_pane == :list
            @selected_func_idx = Math.max(0, @selected_func_idx - 10)
          else
            @code_scroll = Math.max(0, @code_scroll - 10)
          end
        when "page_down", "pagedown"
          if @focus_pane == :list
            @selected_func_idx = Math.min(@filtered_functions.size - 1, @selected_func_idx + 10)
          else
            @code_scroll += 10
          end
        end

        {self, Opal::TEA::Cmd.none}
      end

      private def apply_filter : Nil
        if @search_query.empty?
          @filtered_functions = @functions.dup
        else
          q = @search_query.downcase
          @filtered_functions = @functions.select do |f|
            f.name.downcase.includes?(q) || f.offset.to_s(16).includes?(q)
          end
        end
        @selected_func_idx = 0
      end

      def active_function : Model::Function?
        @filtered_functions[@selected_func_idx]?
      end

      def current_disassembly : String
        fn = active_function
        return "// No function selected" unless fn
        @disasm_cache[fn.offset] ||= begin
          res = @client.cmd("pdf @ 0x#{fn.offset.to_s(16)}").strip
          res.empty? ? @client.cmd("pd 20 @ 0x#{fn.offset.to_s(16)}").strip : res
        end
      end

      def current_decompilation : String
        fn = active_function
        return "// No function selected" unless fn
        @decomp_cache[fn.offset] ||= begin
          res = @client.cmd("pdc @ 0x#{fn.offset.to_s(16)}").strip
          res.empty? || res.includes?("Cannot") ? "// Decompilation unavailable for this function" : res
        end
      end

      def view(width : Int32, height : Int32) : String
        Opal.render_ui(width, height) do |ui|
          ui.vstack do |root|
            # 1. Top Header Tabs
            root.box(border: :none) do |top|
              top.hstack do |h|
                h.tabs(["1: Code Explorer", "2: Sections", "3: Security"], active_index: @active_tab)
                if @searching
                  h.text("  Search: #{@search_query}_", fg: :yellow, bold: true)
                elsif !@search_query.empty?
                  h.text("  Filter: #{@search_query} (Esc to clear)", fg: :dark_gray)
                end
              end
            end

            # 2. Main Content Area
            case @active_tab
            when 0 # Code Explorer
              root.split_view(
                ratio: 0.35,
                focused_pane: @focus_pane == :list ? :first : :second
              ) do |split|
                # Left Pane: Functions Table
                split.first do |left|
                  left.box(
                    title: "Functions (#{@filtered_functions.size})",
                    border_fg: @focus_pane == :list ? :cyan : :white
                  ) do |b|
                    items = @filtered_functions.map_with_index do |f, i|
                      prefix = (i == @selected_func_idx) ? "▶ " : "  "
                      "#{prefix}0x#{f.offset.to_s(16)} #{f.name}"
                    end
                    b.text(items.join("\n"))
                  end
                end

                # Right Pane: Disassembly / Decompilation
                split.second do |right|
                  fn = active_function
                  title = fn ? "Function: #{fn.name} (0x#{fn.offset.to_s(16)})" : "Code View"
                  right.box(
                    title: title,
                    border_fg: @focus_pane == :code ? :cyan : :white
                  ) do |b|
                    if @side_by_side
                      b.split_view(ratio: 0.5) do |code_split|
                        code_split.first do |asm_box|
                          asm_box.box(title: "Disassembly (pdf)", border: :rounded) do |ab|
                            lines = current_disassembly.lines
                            visible = lines[@code_scroll..Math.min(lines.size, @code_scroll + 20)]? || [] of String
                            ab.text(visible.join("\n"), fg: :green)
                          end
                        end
                        code_split.second do |dec_box|
                          dec_box.box(title: "Decompilation (pdc)", border: :rounded) do |db|
                            lines = current_decompilation.lines
                            visible = lines[@code_scroll..Math.min(lines.size, @code_scroll + 20)]? || [] of String
                            db.text(visible.join("\n"), fg: :white)
                          end
                        end
                      end
                    else
                      # Single Pane View
                      content = @show_asm ? current_disassembly : current_decompilation
                      lines = content.lines
                      visible = lines[@code_scroll..Math.min(lines.size, @code_scroll + 20)]? || [] of String
                      b.text(visible.join("\n"))
                    end
                  end
                end
              end
            when 1 # Binary Sections
              sections = @client.sections
              root.box(title: "Binary Sections (#{sections.size})", border_fg: :cyan) do |b|
                b.table(
                  headers: ["Section", "Virtual Addr", "Virtual Size", "Raw Size", "Perms"],
                  header_fg: :cyan
                ) do |tbl|
                  sections.each do |sec|
                    tbl.row([
                      sec.name,
                      "0x#{sec.vaddr.to_s(16)}",
                      "#{sec.vsize} B",
                      "#{sec.size} B",
                      sec.perm || "---",
                    ])
                  end
                end
              end
            when 2 # Security Posture
              sec = @client.security
              root.box(title: "Binary Security Posture Analysis", border_fg: :cyan) do |b|
                b.vstack do |vs|
                  vs.hstack do |hs|
                    hs.text("Security Score: #{sec.score}% ", bold: true)
                    hs.badge(sec.secure? ? " SECURE " : " VULNERABLE ", bg: sec.secure? ? :green : :red)
                  end
                  vs.text("")
                  vs.table(headers: ["Mitigation", "Status", "Description"]) do |tbl|
                    tbl.row(["ASLR / PIC", sec.pic? ? "[✓] ENABLED" : "[✗] DISABLED", "Position Independent Code relocation"])
                    tbl.row(["DEP / NX", sec.nx? ? "[✓] ENABLED" : "[✗] DISABLED", "No-Execute stack/heap memory"])
                    tbl.row(["Stack Canary", sec.canary ? "[✓] ENABLED" : "[✗] DISABLED", "Stack buffer overflow canary guard"])
                    tbl.row(["Relocations", sec.relocs ? "[✓] RETAINED" : "[✗] STRIPPED", "Base relocations present in header"])
                    tbl.row(["Stripped Symbols", sec.stripped ? "[✓] STRIPPED" : "[!] UNSTRIPPED", "Debug symbols stripped"])
                  end
                  vs.text("")
                  if sec.recommendations.empty?
                    vs.text("All security best practices are met.", fg: :green, bold: true)
                  else
                    vs.text("Recommendations:", fg: :yellow, bold: true)
                    sec.recommendations.each do |r|
                      vs.text("  - #{r}", fg: :yellow)
                    end
                  end
                end
              end
            end

            # 3. Bottom Status Bar & Key Help
            root.box(border: :none) do |bot|
              bot.hstack do |h|
                h.text("[Tab] Focus Pane  |  ", fg: :cyan)
                h.text("[s] Toggle Split  |  ", fg: :cyan)
                h.text("[a/c] Asm/Decomp  |  ", fg: :cyan)
                h.text("[/] Filter  |  ", fg: :cyan)
                h.text("[j/k] Navigate  |  ", fg: :cyan)
                h.text("[1-3] Switch Tabs  |  ", fg: :cyan)
                h.text("[q] Quit", fg: :red, bold: true)
              end
            end
          end
        end
      end
    end
  end
end
