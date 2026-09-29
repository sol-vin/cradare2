require "../src/cradare2"

target = ARGV.first? || "malloc://2048"
puts "Opening #{target} in read-write mode..."

Cradare2.open(target, write: true) do |r2|
  # Write a test string and byte pattern
  puts "\nWriting data into memory..."
  r2.memory.write_string(0x100, "Lapis Godot Engine Extension")
  r2.memory.write_u32(0x200, 0x1337BEEF_u32)
  r2.memory.write(0x300, Bytes[0x90, 0x90, 0xCC, 0xC3]) # NOP NOP INT3 RET

  # Read back
  str = r2.memory.read_string(0x100)
  u32_val = r2.memory.read_u32(0x200)
  bytes = r2.memory.read(0x300, 4)

  puts "\n=== Verified Memory Contents ==="
  puts "String @ 0x100: #{str.inspect}"
  puts "UInt32 @ 0x200: 0x#{u32_val.to_s(16).upcase}"
  puts "Bytes  @ 0x300: #{bytes.hexstring.upcase}"

  # Search memory
  puts "\n=== Memory Search ==="
  string_hits = r2.memory.search_string("Lapis")
  puts "Found 'Lapis' at offsets: #{string_hits.map { |h| "0x#{h.to_s(16)}" }}"

  pattern_hits = r2.memory.search_bytes(Bytes[0x90, 0x90, 0xCC])
  puts "Found pattern [90 90 CC] at offsets: #{pattern_hits.map { |h| "0x#{h.to_s(16)}" }}"

  # Hexdump
  puts "\n=== Hexdump of 0x100 - 0x140 ==="
  puts r2.memory.hexdump(0x100, size: 48)
end
