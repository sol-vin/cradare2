require "../src/cradare2"

target = ARGV.first? || "C:\\Users\\Ian\\scoop\\shims\\r2.exe"

puts "=========================================================="
puts "  Binary & Dynamic Library Symbol Inspector"
puts "=========================================================="
puts "Target binary: #{target}\n"

Cradare2.open(target) do |r2|
  # Run analysis
  r2.analyze.all

  # 1. Target metadata
  info = r2.info
  puts "--> 1. Binary Architecture & Format:"
  puts "    Format:       #{info.format}"
  puts "    Architecture: #{info.arch} (#{info.bits}-bit)"
  puts "    OS:           #{info.os}"
  puts "    Base Address: 0x#{info.base_address.to_s(16)}"
  puts "    PIC/PIE:      #{info.pic?}"

  # 2. Exported functions
  puts "\n--> 2. Exported Symbols (Total: #{r2.exports.size}):"
  if r2.exports.empty?
    puts "    (No exports found in binary)"
  else
    r2.exports.first(10).each do |exp|
      puts "    * 0x#{exp.offset.to_s(16)}: #{exp.display_name} (ordinal: #{exp.ordinal || 0})"
    end
  end

  # 3. Filtered symbol query
  puts "\n--> 3. Searching Functions Matching Pattern:"
  main_funcs = r2.functions_matching(/main|entry/i)
  main_funcs.each do |fn|
    puts "    * 0x#{fn.offset.to_s(16)}: #{fn.name} (size: #{fn.size} bytes)"
  end

  # 4. Imported dependencies
  puts "\n--> 4. Imported Functions (Total: #{r2.imports.size}):"
  r2.imports.first(8).each do |imp|
    puts "    * #{imp.name} @ 0x#{imp.offset.to_s(16)}"
  end

  # 5. Sections
  puts "\n--> 5. Memory Sections:"
  r2.sections.each do |sec|
    puts "    * #{sec.name.ljust(12)}: 0x#{sec.vaddr.to_s(16)} [#{sec.perm}] (#{sec.size} bytes)"
  end
end

puts "\nInspection complete."
