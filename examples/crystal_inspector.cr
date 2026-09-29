require "../src/cradare2"

# Example: Inspecting a Crystal Binary and Runtime Memory Layout
#
# Usage:
#   crystal run examples/crystal_inspector.cr -- [path_to_binary]

binary_path = ARGV[0]?

if binary_path && File.exists?(binary_path)
  puts "==> Analyzing Crystal binary: #{binary_path}"
  Cradare2.open(binary_path) do |r2|
    r2.analyze.all

    if r2.crystal.crystal_binary?
      puts "[+] Crystal binary detected!"
      if ep = r2.crystal.entrypoint
        puts "    Entrypoint (__crystal_main): 0x#{ep.to_s(16)}"
      end

      classes = r2.crystal.classes
      puts "    Discovered #{classes.size} Crystal classes/modules:"
      classes.first(10).each do |cls|
        methods = r2.crystal.methods_for_class(cls)
        puts "    - #{cls} (#{methods.size} methods)"
      end

      gc_fns = r2.crystal.gc_functions
      puts "    Boehm GC functions found: #{gc_fns.size}"
    else
      puts "[-] Not recognized as a Crystal binary."
    end
  end
else
  puts "==> Demonstrating Crystal inspection with Mock Transport"
  # Set up mock session representing an analyzed Crystal binary
  r2 = Cradare2.mock
  mock = r2.transport.as(Cradare2::Transport::MockTransport)

  # Mock symbols and functions
  mock.on("isj", <<-JSON
      [
        {"name":"sym.__crystal_main","vaddr":4198400,"size":100},
        {"name":"sym.imp.GC_init","vaddr":4199000,"size":20},
        {"name":"sym.imp.GC_malloc","vaddr":4199050,"size":30},
        {"name":"sym.*~Player#score:Int32","vaddr":4200100,"size":32}
      ]
    JSON
  )

  mock.on("aflj", <<-JSON
      [
        {"offset":4198400,"name":"sym.__crystal_main","size":100,"realsz":100,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4198400,"maxbound":4198500,"calltype":"","difftype":"","nargs":0,"nlocals":0},
        {"offset":4200000,"name":"sym.*~String#bytesize:Int32","size":24,"realsz":24,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4200000,"maxbound":4200024,"calltype":"","difftype":"","nargs":1,"nlocals":0},
        {"offset":4200050,"name":"sym.*~String#to_slice:Slice(UInt8)","size":32,"realsz":32,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4200050,"maxbound":4200082,"calltype":"","difftype":"","nargs":1,"nlocals":0},
        {"offset":4200100,"name":"sym.*~Player#score:Int32","size":32,"realsz":32,"cc":1,"nbbs":1,"edges":0,"ebbs":1,"minbound":4200100,"maxbound":4200132,"calltype":"","difftype":"","nargs":1,"nlocals":0}
      ]
    JSON
  )

  # Mock memory for Crystal String: "Hello, Crystal!"
  mock.on("pxj 4 @ 0x1000", "[42, 0, 0, 0]") # type_id = 42
  mock.on("pxj 4 @ 0x1004", "[15, 0, 0, 0]") # bytesize = 15
  mock.on("pxj 4 @ 0x1008", "[15, 0, 0, 0]") # length = 15
  mock.on("pxj 15 @ 0x100c", "[72, 101, 108, 108, 111, 44, 32, 67, 114, 121, 115, 116, 97, 108, 33]")

  puts "[+] Is Crystal Binary: #{r2.crystal.crystal_binary?}"
  puts "[+] Entrypoint: 0x#{r2.crystal.entrypoint.try(&.to_s(16))}"

  puts "\n[+] Discovered Crystal Classes:"
  r2.crystal.classes.each do |cls|
    methods = r2.crystal.methods_for_class(cls)
    puts "  Class: #{cls}"
    methods.each do |m|
      info = r2.crystal.parse_symbol(m.name)
      puts "    -> #{info.method_name} (at 0x#{m.offset.to_s(16)})"
    end
  end

  puts "\n[+] Reading Crystal String object at 0x1000:"
  str_obj = r2.crystal.read_string(0x1000_u64)
  puts "  Address  : 0x#{str_obj.address.to_s(16)}"
  puts "  Type ID  : #{str_obj.type_id}"
  puts "  Bytesize : #{str_obj.bytesize}"
  puts "  Length   : #{str_obj.length}"
  puts "  Value    : \"#{str_obj.value}\""

  r2.close
end
