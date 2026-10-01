require "../src/cradare2"

target = ARGV.first? || "malloc://4096"
puts "Opening target: #{target}"

Cradare2.open(target, write: true) do |r2|
  puts "\n=== Defining Custom Types & Decoding Structs ==="

  # 1. Define a C/Engine struct format for a 24-byte Godot Variant:
  #    type_tag: UInt32 ('d')
  #    flags:    UInt16 ('w')
  #    padding:  UInt16 ('w')
  #    val0:     UInt64 ('q')
  #    val1:     UInt64 ('q')
  puts "Defining custom struct format: 'godot_variant'..."
  r2.types.define_struct("godot_variant", [
    {"d", "type_tag"},
    {"w", "flags"},
    {"w", "padding"},
    {"q", "val0"},
    {"q", "val1"},
  ])

  # 2. Write a simulated Variant into memory at offset 0x100:
  #    type_tag = 5 (Vector2), flags = 0, padding = 0, val0 = 0x4024000000000000 (Float64 10.0), val1 = 0x4034000000000000 (Float64 20.0)
  r2.memory.write_u32(0x100, 5_u32)
  r2.memory.write_u16(0x104, 0_u16)
  r2.memory.write_u16(0x106, 0_u16)
  r2.memory.write_u64(0x108, 0x4024000000000000_u64)
  r2.memory.write_u64(0x110, 0x4034000000000000_u64)

  # 3. Read and decode the struct using print_format (pfj)
  puts "\nDecoding struct at offset 0x100 via radare2 'pfj':"
  decoded = r2.types.print_format("godot_variant", 0x100)

  decoded.each do |field, val|
    puts "  #{field.ljust(12)}: #{val}"
  end
end
