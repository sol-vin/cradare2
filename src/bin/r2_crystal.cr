require "option_parser"
require "../cradare2"
require "../cradare2/plugin/dispatcher"
require "../cradare2/plugin/server"

# r2-crystal: radare2 Crystal Plugin & Analysis Tool
#
# Usage:
#   Inside radare2:
#     #!pipe r2-crystal [command]
#
#   Interactive pipe server:
#     #!pipe r2-crystal --server
#
#   Standalone:
#     r2-crystal [options] <binary> [command] [args...]
#

json_mode = false
server_mode = false
source_paths = [] of String
path_mappings = Hash(String, String).new
timeout_seconds = 10
verbose = false

parser = OptionParser.new do |opts|
  opts.banner = <<-BANNER
  r2-crystal #{Cradare2::VERSION} - radare2 Crystal Plugin CLI & In-Session Runner

  Usage:
    Standalone:
      r2-crystal [options] <binary> [command] [args...]
    Inside radare2:
      #!pipe r2-crystal [command] [args...]
      #!pipe r2-crystal --server

  Options:
  BANNER

  opts.on("-j", "--json", "Output results in JSON format") do
    json_mode = true
  end

  opts.on("-s", "--server", "Run as interactive radare2 pipe server loop") do
    server_mode = true
  end

  opts.on("-I DIR", "--include DIR", "Add source search directory") do |dir|
    source_paths << dir
  end

  opts.on("-m MAPPING", "--map MAPPING", "Remap source path prefix (e.g. /build/src=C:/src)") do |mapping|
    parts = mapping.split('=')
    if parts.size == 2
      path_mappings[parts[0]] = parts[1]
    end
  end

  opts.on("-t SECONDS", "--timeout SECONDS", "Set command execution timeout in seconds (default: 10)") do |t|
    timeout_seconds = t.to_i? || 10
  end

  opts.on("-v", "--verbose", "Print debug and timing diagnostics to stderr") do
    verbose = true
  end

  opts.on("-h", "--help", "Show this help menu") do
    puts opts
    exit(0)
  end

  opts.on("--version", "Show r2-crystal version") do
    puts "r2-crystal #{Cradare2::VERSION}"
    exit(0)
  end
end

parser.parse(ARGV)

# Check if running in-session (R2PIPE_IN or R2PIPE_PATH set)
if ENV["R2PIPE_IN"]? || ENV["R2PIPE_PATH"]? || ARGV.first? == "#!pipe"
  session_args = (ARGV.first? == "#!pipe" ? ARGV[1..] : ARGV)
  Cradare2.open("#!pipe", timeout: timeout_seconds.seconds) do |client|
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    if server_mode
      Cradare2::Plugin::Server.run(dispatcher)
    elsif session_args.empty?
      suffix = json_mode ? " -j" : ""
      puts dispatcher.dispatch("info#{suffix}")
      puts dispatcher.dispatch("lines sync#{suffix}")
    else
      suffix = json_mode ? " -j" : ""
      cmd_line = session_args.join(" ") + suffix
      puts dispatcher.dispatch(cmd_line)
    end
  end
  exit(0)
end

if ARGV.empty?
  puts parser
  exit(0)
end

# First positional argument is the binary path
binary_path = ARGV.shift
unless File.file?(binary_path)
  STDERR.puts "#{Cradare2::Util::CLIFormatter.badge("ERROR", bg: :red)} Binary file '#{binary_path}' not found."
  exit(1)
end

options = Cradare2::Options.new(
  target: binary_path,
  timeout: timeout_seconds.seconds,
  source_paths: source_paths,
  path_mappings: path_mappings
)

Cradare2.open(options) do |client|
  if verbose
    client.on_command do |cmd, dur, success|
      badge_col = success ? :green : :red
      status_badge = Cradare2::Util::CLIFormatter.badge(success ? "OK" : "ERR", bg: badge_col)
      STDERR.puts "#{status_badge} [r2 trace] #{cmd} (#{dur.total_milliseconds.round(2)}ms)"
    end
  end

  # Auto-load PDB on Windows if present
  pdb_path = binary_path.sub(/\.exe$/i, ".pdb")
  if File.file?(pdb_path)
    client.cmd("idp \"#{pdb_path}\"")
    client.cmd(".idpi*")
  end

  # Configure source search paths and remapping rules
  source_paths.each { |p| client.crystal.lines.reader.search_paths << p }
  path_mappings.each { |rem, loc| client.crystal.lines.reader.map_path(rem, loc) }

  # Run analysis if needed for function/call graph commands
  if ARGV.empty? || ARGV.any? { |a| ["interleaved", "classes", "methods", "demangle-all", "il", "asm", "lines"].includes?(a) }
    client.analyze.calls
  end

  dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

  if server_mode
    Cradare2::Plugin::Server.run(dispatcher)
  elsif ARGV.empty?
    suffix = json_mode ? " -j" : ""
    puts dispatcher.dispatch("info#{suffix}")
    puts
    puts dispatcher.dispatch("lines#{suffix}")
  else
    suffix = json_mode ? " -j" : ""
    cmd_line = ARGV.join(" ") + suffix
    puts dispatcher.dispatch(cmd_line)
  end
end
