require "../src/cradare2"

target = ARGV.first? || "malloc://4096"
puts "Opening target: #{target}"

Cradare2.open(target, write: true) do |r2|
  puts "\n=== Managing Radare2 Flags & Spaces ==="

  # 1. Switch to custom Flag Space 'engine'
  puts "Switching to flag space: 'engine'"
  r2.flags.space("engine")
  puts "Current space: #{r2.flags.current_space}"

  # 2. Set individual flags
  r2.flags.set("engine.main_loop", 0x1000)
  r2.flags.set("engine.physics_step", 0x1100)
  r2.flags.set("engine.render_frame", 0x1200)

  puts "Flag engine.main_loop address: 0x#{r2.flags.get("engine.main_loop").try(&.to_s(16))}"

  # 3. Batch set flags in 'lapis' space
  puts "\nSwitching to flag space: 'lapis'"
  r2.flags.space("lapis")

  lapis_symbols = {
    "lapis.Node.ready"   => 0x2000_u64,
    "lapis.Node.process" => 0x2100_u64,
    "lapis.Node.exit"    => 0x2200_u64,
  }
  r2.flags.batch_set(lapis_symbols)

  # 4. List all active spaces
  puts "All flag spaces in session: #{r2.flags.spaces.join(", ")}"

  # 5. Filter flags matching pattern
  puts "\nMatching flags in 'lapis':"
  r2.flags.matching(/Node/).each do |f|
    puts "  #{f.name.ljust(25)} @ 0x#{f.offset.to_s(16)}"
  end

  # 6. Safe Base64 Comments
  puts "\n=== Annotating Safe Base64 Comments ==="
  r2.comments.set(0x2000, "Lapis::Node#_ready() [Called on scene enter]")
  r2.comments.set(0x2100, "Lapis::Node#_process(delta: Float64)")

  puts "Comment @ 0x2000: #{r2.comments.get(0x2000)}"
  puts "Comment @ 0x2100: #{r2.comments.get(0x2100)}"
end
