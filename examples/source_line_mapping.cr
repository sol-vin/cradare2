require "../src/cradare2"

puts "=== Source Line Mapping & Path Remapping ==="

# 1. Configure SourceReader with custom path remapping
reader = Cradare2::Lines::SourceReader.new
reader.map_path("/github/workspace/src", "C:/projects/game/src")

# Preload virtual source code for demonstration
virtual_source = <<-CR
module Game
  def self.calculate(x : Int32)
    x * 2 + 1
  end
end
CR

reader.set_virtual_source("C:/projects/game/src/calculator.cr", virtual_source)

# 2. Build synthetic instruction mappings
loc = Cradare2::Lines::SourceLocation.new("C:/projects/game/src/calculator.cr", 3)
mapping1 = Cradare2::Lines::InstructionMapping.new(0x140001000_u64, 4, "mov eax, ecx", "89c8", loc, "calculate")
mapping2 = Cradare2::Lines::InstructionMapping.new(0x140001004_u64, 2, "shl eax, 1", "d1e0", loc, "calculate")
mapping3 = Cradare2::Lines::InstructionMapping.new(0x140001006_u64, 3, "add eax, 1", "83c001", loc, "calculate")

source_map = Cradare2::Lines::SourceMap.new([mapping1, mapping2, mapping3], reader)

# 3. Query instruction by address using O(log N) binary search
query_addr = 0x140001005_u64
if match = source_map.find_instruction_containing(query_addr)
  puts "Address 0x#{query_addr.to_s(16)} is inside instruction:"
  puts "  0x#{match.address.to_s(16)}: #{match.opcode} (#{match.size} bytes)"
  puts "  Source: #{match.location.try(&.file)}:#{match.location.try(&.line)}"
end

# 4. Generate interleaved source and assembly listing
puts "\nInterleaved Source & Assembly View:"
puts source_map.format_interleaved_view("calculate")
