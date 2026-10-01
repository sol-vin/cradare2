require "../cradare2"
require "../cradare2/plugin/dispatcher"

# r2-crystal: radare2 Crystal Plugin & Analysis Tool
#
# Usage:
#   Inside radare2:
#     #!pipe r2-crystal [command]
#
#   Standalone:
#     r2-crystal <binary> [command]
#

def run_in_session(args : Array(String))
  Cradare2.open("#!pipe") do |client|
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    if args.empty?
      # Run default detect & sync
      puts dispatcher.dispatch("info")
      puts dispatcher.dispatch("lines sync")
    else
      cmd_line = args.join(" ")
      puts dispatcher.dispatch(cmd_line)
    end
  end
end

def run_standalone(args : Array(String))
  if args.empty? || args.first == "-h" || args.first == "--help"
    puts <<-USAGE
    r2-crystal - radare2 Crystal Plugin CLI & In-Session Runner

    Usage:
      Standalone:
        r2-crystal <binary> [command] [args...]
      Inside radare2:
        #!pipe r2-crystal [command] [args...]

    Examples:
      r2-crystal app.exe lines
      r2-crystal app.exe lines sync
      r2-crystal app.exe demangle-all
      r2-crystal app.exe interleaved main
      r2-crystal app.exe asm app.cr:15
    USAGE
    exit(0)
  end

  # Check if running in-session (R2PIPE_IN or R2PIPE_PATH set)
  if ENV["R2PIPE_IN"]? || ENV["R2PIPE_PATH"]? || args.first == "#!pipe"
    session_args = (args.first == "#!pipe" ? args[1..] : args)
    run_in_session(session_args)
    return
  end

  # First argument is the binary path
  binary_path = args.shift
  unless File.file?(binary_path)
    STDERR.puts "Error: File '#{binary_path}' not found."
    exit(1)
  end

  Cradare2.open(binary_path) do |client|
    # Auto-load PDB on Windows if present
    pdb_path = binary_path.sub(/\.exe$/i, ".pdb")
    if File.file?(pdb_path)
      client.cmd("idp \"#{pdb_path}\"")
      client.cmd(".idpi*")
    end

    # Run analysis if needed for function/call graph commands
    if args.empty? || args.any? { |a| ["interleaved", "classes", "methods", "demangle-all", "il", "asm", "lines"].includes?(a) }
      client.analyze.calls
    end

    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client)

    if args.empty?
      puts dispatcher.dispatch("info")
      puts
      puts dispatcher.dispatch("lines")
    else
      cmd_line = args.join(" ")
      puts dispatcher.dispatch(cmd_line)
    end
  end
end

run_standalone(ARGV)
