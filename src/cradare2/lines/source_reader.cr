module Cradare2
  module Lines
    # Reads, caches, and provides contextual snippets of source code files from disk or memory.
    class SourceReader
      # In-memory file cache: Normalized Path => Array of lines
      @cache = Hash(String, Array(String)).new
      getter search_paths : Array(String)

      def initialize(search_paths : Array(String) = [] of String)
        @search_paths = search_paths.map { |p| normalize_path(p) }
        @search_paths << normalize_path(Dir.current) unless @search_paths.includes?(normalize_path(Dir.current))
      end

      # Adds an in-memory virtual source file (useful for mocking, tests, or slurped source).
      def register_source(file : String, content : String) : Nil
        lines = content.lines
        @cache[normalize_path(file)] = lines
        @cache[File.basename(file)] = lines
      end

      # Clears the cached file contents.
      def clear_cache : Nil
        @cache.clear
      end

      # Returns true if the file exists on disk or in the memory cache.
      def exists?(file : String) : Bool
        norm = normalize_path(file)
        return true if @cache.has_key?(norm) || @cache.has_key?(File.basename(file))
        resolve_path(file) != nil
      end

      # Alias for exists?
      def has_file?(file : String) : Bool
        exists?(file)
      end

      # Returns the total line count for a file, or 0 if not found.
      def line_count(file : String) : Int32
        get_file_lines(file).try(&.size) || 0
      end

      # Reads a single line of text from `file` at `line_num` (1-indexed).
      # Returns nil if file or line does not exist.
      def read_line(file : String, line_num : Int32) : String?
        return nil if line_num < 1
        lines = get_file_lines(file)
        return nil unless lines
        lines[line_num - 1]?
      end

      # Reads a contextual block of lines centered around `line_num` with symmetric window.
      def read_context(file : String, line_num : Int32, window : Int32) : Array(NamedTuple(line: Int32, text: String, current: Bool))
        read_context(file, line_num, before: window, after: window)
      end

      # Reads a contextual block of lines centered around `line_num` with symmetric window keyword.
      def read_context(file : String, line_num : Int32, *, window : Int32) : Array(NamedTuple(line: Int32, text: String, current: Bool))
        read_context(file, line_num, before: window, after: window)
      end

      # Reads a contextual block of lines centered around `line_num` (1-indexed).
      # `before` and `after` specify how many surrounding lines to include.
      def read_context(
        file : String,
        line_num : Int32,
        before : Int32 = 2,
        after : Int32 = 2,
      ) : Array(NamedTuple(line: Int32, text: String, current: Bool))
        lines = get_file_lines(file)
        return [] of NamedTuple(line: Int32, text: String, current: Bool) unless lines

        start_line = Math.max(1, line_num - Math.max(0, before))
        end_line = Math.min(lines.size, line_num + Math.max(0, after))

        result = [] of NamedTuple(line: Int32, text: String, current: Bool)
        (start_line..end_line).each do |l|
          if txt = lines[l - 1]?
            result << {line: l, text: txt, current: l == line_num}
          end
        end
        result
      end

      # Retrieves all lines of a file, caching them in memory.
      def get_file_lines(file : String) : Array(String)?
        norm = normalize_path(file)
        if cached = @cache[norm]?
          return cached
        end

        base = File.basename(file)
        if cached = @cache[base]?
          return cached
        end

        # Resolve actual path on disk
        if resolved = resolve_path(file)
          begin
            lines = File.read_lines(resolved)
            @cache[norm] = lines
            @cache[base] = lines
            @cache[normalize_path(resolved)] = lines
            return lines
          rescue
            return nil
          end
        end

        nil
      end

      # Attempts to find the file either as an absolute path, relative to current dir,
      # or relative to one of the configured `search_paths`.
      def resolve_path(file : String) : String?
        # Direct check
        if File.file?(file)
          return File.expand_path(file)
        end

        # Check relative to search paths
        norm = file.gsub('\\', '/')
        @search_paths.each do |base|
          candidate = File.join(base, norm)
          if File.file?(candidate)
            return File.expand_path(candidate)
          end

          # Try matching by basename in the search path
          base_candidate = File.join(base, File.basename(norm))
          if File.file?(base_candidate)
            return File.expand_path(base_candidate)
          end
        end

        nil
      end

      private def normalize_path(path : String) : String
        path.gsub('\\', '/').downcase
      end
    end
  end
end
