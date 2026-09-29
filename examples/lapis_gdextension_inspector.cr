require "../src/cradare2"

target = ARGV.first? || "C:\\Users\\Ian\\scoop\\shims\\r2.exe"

puts "=========================================================="
puts "  Lapis Godot 4 GDExtension & Binary Diagnostic Tool"
puts "=========================================================="
puts "Target binary: #{target}\n"

Cradare2.open(target) do |r2|
  # Run analysis
  r2.analyze.all

  # 1. GDExtension verification
  puts "--> 1. Verifying GDExtension Exports..."
  check = r2.lapis.verify_gdextension
  puts "    Architecture:      #{check.arch} (#{check.bits}-bit)"
  puts "    Total Exports:     #{check.exports_count}"
  puts "    Entrypoint Found:  #{check.entrypoint_found ? "YES (#{check.entrypoint_name})" : "NO"}"
  puts "    Status:            #{check.valid ? "VALID GDEXTENSION" : "NOT A STANDARD GDEXTENSION"}"
  check.warnings.each do |w|
    puts "    [!] Warning: #{w}"
  end

  # 2. Crystal symbols
  puts "\n--> 2. Searching for Crystal Methods & Types..."
  cr_symbols = r2.lapis.find_crystal_symbols
  if cr_symbols.empty?
    puts "    (No Crystal-mangled symbols detected)"
  else
    puts "    Found #{cr_symbols.size} Crystal symbols (showing first 10):"
    cr_symbols.first(10).each do |sym|
      demangled = Cradare2::Util::Demangler.demangle(sym.name, r2.transport)
      puts "    * 0x#{sym.offset.to_s(16)}: #{demangled}"
    end
  end

  # 3. Godot bindings
  puts "\n--> 3. Searching for Godot GDExtension API Calls..."
  godot_apis = r2.lapis.find_godot_bindings
  if godot_apis.empty?
    puts "    (No Godot C API imports found in this binary)"
  else
    puts "    Found #{godot_apis.size} Godot APIs (showing first 10):"
    godot_apis.first(10).each do |api|
      puts "    * 0x#{api.offset.to_s(16)}: #{api.name}"
    end
  end

  # 4. GC Symbols
  puts "\n--> 4. Crystal Garbage Collection (GC) Symbols..."
  gc_syms = r2.lapis.find_gc_symbols
  if gc_syms.empty?
    puts "    (No Boehm GC symbols found)"
  else
    puts "    Found #{gc_syms.size} GC symbols (e.g. #{gc_syms.first(3).map(&.name).join(", ")})"
  end
end

puts "\nDiagnostic complete."
