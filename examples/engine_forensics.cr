require "../src/cradare2"

target = ARGV.first? || "malloc://8192"
puts "Opening target: #{target}"

Cradare2.open(target, write: true) do |r2|
  puts "\n=== Engine Forensics & Vtable Inspection ==="

  # 1. Simulate a C++ virtual method table (array of function pointers)
  # Write 4 64-bit pointers at 0x1000
  vtable_addr = 0x1000_u64
  r2.memory.write_u64(0x1000, 0x140001000_u64)
  r2.memory.write_u64(0x1008, 0x140001200_u64)
  r2.memory.write_u64(0x1010, 0x140001400_u64)
  r2.memory.write_u64(0x1018, 0x140001600_u64)

  # 2. Read back using read_pointer_array
  ptrs = r2.memory.read_pointer_array(vtable_addr, count: 4)
  puts "Virtual Method Table at 0x#{vtable_addr.to_s(16)}:"
  ptrs.each_with_index do |fn_ptr, idx|
    puts "  slot[#{idx}] -> 0x#{fn_ptr.to_s(16)}"
  end

  # 3. Simulate C-string class names in read-only section
  cstring_addr = 0x500_u64
  r2.memory.write(cstring_addr, "Node2D\0CharacterBody2D\0".to_slice)

  str1 = r2.memory.read_cstring(0x500)
  str2 = r2.memory.read_cstring(0x507)
  puts "\nExtracted Class Names via read_cstring:"
  puts "  String 1 @ 0x500: #{str1}"
  puts "  String 2 @ 0x507: #{str2}"

  # 4. Modules in active session
  puts "\nLoaded Modules / Memory Regions:"
  mods = r2.debug.modules
  if mods.empty?
    puts "  (No multi-module image maps active in synthetic malloc target)"
  else
    mods.each do |mod|
      puts "  #{mod.name.ljust(20)} [0x#{mod.base_address.to_s(16)} - 0x#{mod.end_address.to_s(16)}]"
    end
  end
end
