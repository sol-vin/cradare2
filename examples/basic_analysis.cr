require "../src/cradare2"

target = ARGV.first? || "malloc://1024"
puts "Opening target: #{target}"

Cradare2.open(target) do |r2|
  # Run analysis
  puts "Running binary analysis..."
  r2.analyze.all

  # Target metadata
  info = r2.info
  puts "\n=== Binary Information ==="
  puts "Format:       #{info.format}"
  puts "Architecture: #{info.arch} (#{info.bits}-bit)"
  puts "OS:           #{info.os}"
  puts "Base Address: 0x#{info.base_address.to_s(16)}"
  puts "PIC:          #{info.pic?}"

  # Functions
  puts "\n=== Discovered Functions ==="
  funcs = r2.functions
  if funcs.empty?
    puts "  (No functions detected in target)"
  else
    funcs.first(5).each do |fn|
      puts "  #{fn.name} @ 0x#{fn.offset.to_s(16)} (size: #{fn.size} bytes, #{fn.nbbs || 0} basic blocks)"
    end
  end

  # Sections
  puts "\n=== Sections ==="
  r2.sections.first(5).each do |sec|
    puts "  #{sec.name.ljust(12)}: 0x#{sec.vaddr.to_s(16)} - #{sec.size} bytes [#{sec.perm}]"
  end

  # Disassemble first 5 instructions
  puts "\n=== Disassembly at Entry ==="
  puts r2.disasm.text(5)
end
