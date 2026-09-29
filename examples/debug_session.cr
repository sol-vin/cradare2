require "../src/cradare2"

target = ARGV.first? || "C:\\Users\\Ian\\scoop\\shims\\r2.exe"

puts "Launching debugger session for: #{target}..."

# Launch target with debug: true
Cradare2.open(target, debug: true) do |r2|
  # Debugger DSL block
  r2.debug do |d|
    puts "PID: #{d.pid || "spawned"}"

    # Set breakpoint at entrypoint
    puts "Setting breakpoint at entry..."
    d.breakpoint("entry0")

    puts "\nActive Breakpoints:"
    d.breakpoints.each do |bp|
      puts "  BP at 0x#{bp.offset.to_s(16)} (enabled: #{bp.enabled?})"
    end

    # Inspect initial registers
    regs = d.registers
    puts "\nInitial CPU Registers:"
    puts "  PC (Instruction Pointer): 0x#{regs.pc.to_s(16)}"
    puts "  SP (Stack Pointer):       0x#{regs.sp.to_s(16)}"
    puts "  BP (Frame Pointer):       0x#{regs.bp.to_s(16)}"

    # Inspect loaded modules / memory maps
    puts "\nLoaded Memory Maps (First 5):"
    d.maps.first(5).each do |m|
      puts "  #{m.name.ljust(20)}: 0x#{m.addr.to_s(16)} - 0x#{m.addr_end.to_s(16)} [#{m.perm}]"
    end

    # Step one instruction
    puts "\nStepping one instruction..."
    d.step

    # Inspect updated instruction pointer
    new_regs = d.registers
    puts "Updated PC: 0x#{new_regs.pc.to_s(16)}"
  end
end

puts "\nDebugger session cleanly finished."
