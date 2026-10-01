require "../models/module_info"
require "../models/register"
require "../models/breakpoint"
require "../models/stack_frame"
require "../models/memory_map"
require "../models/thread"
require "../models/crash_diagnosis"
require "../models/telescope"
require "../models/process_info"
require "../analysis/memory_classifier"
require "../util/demangler"
require "../address"

module Cradare2
  module DSL
    # High-level debugger DSL for controlling execution, breakpoints, registers, memory maps, and crash reports.
    class Debugger
      def initialize(@client : Client)
      end

      private def addr_s(address : Address) : String
        case address
        when Int
          "0x#{address.to_s(16)}"
        else
          address.to_s
        end
      end

      # Continues execution of the debugged process (dc).
      def continue : self
        @client.cmd("dc")
        self
      end

      # Continues execution back / reverse continue until hitting a breakpoint (dcb).
      def continue_back : self
        @client.cmd("dcb")
        self
      end

      # Continues execution until reaching the specified target address (dcu).
      def continue_until(address : Address) : self
        @client.cmd("dcu #{addr_s(address)}")
        self
      end

      # Continues execution until returning from the current function (dcr).
      def continue_until_ret : self
        @client.cmd("dcr")
        self
      end

      # Continues execution until the next call instruction (dcc).
      def continue_until_call : self
        @client.cmd("dcc")
        self
      end

      # Continues execution until the next system call (dcs).
      def continue_until_syscall : self
        @client.cmd("dcs")
        self
      end

      # Steps one or more machine instructions (ds).
      def step(count : Int32 = 1) : self
        if count <= 1
          @client.cmd("ds")
        else
          @client.cmd("ds #{count}")
        end
        self
      end

      # Steps over calls or compound instructions (dso).
      def step_over(count : Int32 = 1) : self
        if count <= 1
          @client.cmd("dso")
        else
          @client.cmd("dso #{count}")
        end
        self
      end

      # Steps until exiting current stack frame / function finish (dsf).
      def step_out : self
        @client.cmd("dsf")
        self
      end

      # Alias for step_out.
      def finish : self
        step_out
      end

      # Steps one or more high-level source lines (dsl).
      def step_source(lines : Int32 = 1) : self
        if lines <= 1
          @client.cmd("dsl")
        else
          @client.cmd("dsl #{lines}")
        end
        self
      end

      # Steps back one machine instruction in reversible debugging (dsb).
      def step_back : self
        @client.cmd("dsb")
        self
      end

      # Continues execution until reaching the specified target address (dsu).
      def step_until(address : Address) : self
        @client.cmd("dsu #{addr_s(address)}")
        self
      end

      # Sets a software breakpoint at the given address or symbol (db).
      def breakpoint(target : Address) : self
        @client.cmd("db #{addr_s(target)}")
        self
      end

      # Sets a hardware execution breakpoint at the given address or symbol (dbH).
      def hardware_breakpoint(target : Address) : self
        @client.cmd("dbH #{addr_s(target)}")
        self
      end

      # Alias for hardware_breakpoint.
      def hw_breakpoint(target : Address) : self
        hardware_breakpoint(target)
      end

      # Sets a memory watchpoint on read ('r'), write ('w'), or read/write ('rw') access (dbw).
      def watchpoint(target : Address, access : Symbol = :rw) : self
        mode = case access
               when :r, :read
                 "r"
               when :w, :write
                 "w"
               else
                 "rw"
               end
        @client.cmd("dbw #{addr_s(target)} #{mode}")
        self
      end

      # Removes a breakpoint or watchpoint at the given address or symbol (db-).
      def remove_breakpoint(target : Address) : self
        @client.cmd("db- #{addr_s(target)}")
        self
      end

      # Alias for remove_breakpoint to explicitly remove a watchpoint.
      def remove_watchpoint(target : Address) : self
        remove_breakpoint(target)
      end

      # Removes all breakpoints and watchpoints (db-*).
      def clear_breakpoints : self
        @client.cmd("db-*")
        self
      end

      # Enables a breakpoint at the specified target (dbe).
      def enable_breakpoint(target : Address) : self
        @client.cmd("dbe #{addr_s(target)}")
        self
      end

      # Disables a breakpoint at the specified target without deleting it (dbd).
      def disable_breakpoint(target : Address) : self
        @client.cmd("dbd #{addr_s(target)}")
        self
      end

      # Enables all breakpoints in the session (dbe*).
      def enable_all_breakpoints : self
        @client.cmd("dbe*")
        self
      end

      # Disables all breakpoints in the session (dbd*).
      def disable_all_breakpoints : self
        @client.cmd("dbd*")
        self
      end

      # Toggles a breakpoint at the target address (dbs).
      def toggle_breakpoint(target : Address) : self
        @client.cmd("dbs #{addr_s(target)}")
        self
      end

      # Assigns a descriptive name or label to a breakpoint (dbn <name> @ <target>).
      def name_breakpoint(target : Address, name : String) : self
        @client.cmd("dbn #{name} @ #{addr_s(target)}")
        self
      end

      # Sets an expression condition on a breakpoint (dbx <condition> @ <target>).
      def set_breakpoint_condition(target : Address, condition : String) : self
        @client.cmd("dbx #{condition} @ #{addr_s(target)}")
        self
      end

      # Sets a software breakpoint with an associated condition expression.
      def conditional_breakpoint(target : Address, condition : String) : self
        breakpoint(target)
        set_breakpoint_condition(target, condition)
        self
      end

      # Sets a command to execute when hitting a breakpoint (dbc).
      def set_breakpoint_command(target : Address, command : String) : self
        @client.cmd("dbc #{addr_s(target)} #{command}")
        self
      end

      # Sets a tracepoint / logpoint that executes a command upon hit and immediately continues execution without stopping (dbC).
      def tracepoint(target : Address, command : String) : self
        breakpoint(target)
        @client.cmd("dbC #{addr_s(target)} #{command}")
        self
      end

      # Alias for tracepoint.
      def logpoint(target : Address, command : String) : self
        tracepoint(target, command)
      end

      # Sets a breakpoint at a source code file and line number.
      # If mapped in Crystal/DWARF line metadata, resolves the target address; otherwise falls back to `dbl file:line`.
      def breakpoint_at_source(file : String, line : Int32) : self
        begin
          mappings = @client.crystal.lines.for_line(file, line)
          if first_mapping = mappings.first?
            return breakpoint(first_mapping.address)
          end
        rescue
        end
        @client.cmd("dbl #{file}:#{line}")
        self
      end

      # Returns list of active breakpoints as typed models.
      def breakpoints : Array(Model::Breakpoint)
        @client.cmdj("dbj", as: Array(Model::Breakpoint))
      rescue
        [] of Model::Breakpoint
      end

      # Finds an active breakpoint located at the specified address.
      def find_breakpoint(target : Address) : Model::Breakpoint?
        target_u64 = AddressUtils.to_u64?(target)
        target_s = addr_s(target)
        breakpoints.find do |bp|
          (target_u64 && bp.address == target_u64) || bp.name == target_s
        end
      end

      # Checks whether a breakpoint is active at the specified address.
      def breakpoint_at?(target : Address) : Bool
        !find_breakpoint(target).nil?
      end

      # Returns only software execution breakpoints.
      def software_breakpoints : Array(Model::Breakpoint)
        breakpoints.select(&.software?)
      end

      # Returns only hardware breakpoints.
      def hardware_breakpoints : Array(Model::Breakpoint)
        breakpoints.select(&.hardware?)
      end

      # Returns only memory watchpoints.
      def watchpoints : Array(Model::Breakpoint)
        breakpoints.select(&.watchpoint?)
      end

      # Returns current CPU registers as a strongly typed `Registers` model.
      def registers : Model::Registers
        @client.cmdj("drj", as: Model::Registers)
      rescue
        Model::Registers.new
      end

      # Reads a single register value by name.
      def register(name : String) : UInt64
        registers[name]
      end

      # Sets a register to a specific value (e.g. set_register("rax", 0x1234)).
      def set_register(name : String, value : UInt64) : self
        @client.cmd("dr #{name}=0x#{value.to_s(16)}")
        self
      end

      # Inspects telescoping pointer references for all registers (drrj).
      def telescope : Array(Model::TelescopeEntry)
        @client.cmdj("drrj", as: Array(Model::TelescopeEntry))
      rescue
        [] of Model::TelescopeEntry
      end

      # Pushes / takes a snapshot of current register states (drs+).
      def snapshot_registers : self
        @client.cmd("drs+")
        self
      end

      # Pops / restores register states from the previous snapshot (drs-).
      def restore_registers : self
        @client.cmd("drs-")
        self
      end

      # Compares current CPU registers against a baseline Registers snapshot.
      def diff_registers(baseline : Model::Registers) : Hash(String, Tuple(UInt64, UInt64))
        registers.diff(baseline)
      end

      # Returns the call stack / backtrace frames (dbtj).
      def backtrace : Array(Model::StackFrame)
        @client.cmdj("dbtj", as: Array(Model::StackFrame))
      rescue
        [] of Model::StackFrame
      end

      # Returns list of demangled backtrace function symbols.
      def backtrace_symbols : Array(String)
        backtrace.map do |frame|
          Util::Demangler.demangle(frame.function, @client.transport)
        end
      end

      # Returns the loaded memory maps / regions (dmj).
      def maps : Array(Model::MemoryMap)
        @client.cmdj("dmj", as: Array(Model::MemoryMap))
      rescue
        [] of Model::MemoryMap
      end

      # Returns loaded PE/ELF/Mach-O binary modules in the debugged process (dmmj, with fallback to grouped dmj).
      def modules : Array(Model::ModuleInfo)
        begin
          res = @client.cmdj("dmmj", as: Array(Model::ModuleInfo))
          return res unless res.empty?
        rescue
        end

        group_maps_by_module(maps)
      end

      # Returns the loaded binary module containing the specified address, or nil if unmapped.
      def module_at(address : Address) : Model::ModuleInfo?
        addr_u64 = AddressUtils.to_u64?(address)
        return nil unless addr_u64
        modules.find { |mod| mod.contains?(addr_u64) }
      end

      # Returns the base load address of a specific loaded module by name (e.g. "game.dll" or "godot.exe").
      def base_address_of(module_name : String) : UInt64?
        clean_name = module_name.gsub('\\', '/').split('/').reject(&.empty?).last?.try(&.downcase) || module_name.downcase
        matching = modules.find do |m|
          m_clean = m.name.gsub('\\', '/').split('/').reject(&.empty?).last?.try(&.downcase) || m.name.downcase
          m.name.downcase == clean_name ||
            m_clean == clean_name ||
            m.name.downcase.includes?(clean_name)
        end
        matching.try(&.base_address)
      end

      # Checks if an address represents a stale vtable pointer (pointing outside all currently mapped modules).
      def stale_vtable?(address : UInt64) : Bool
        return false if address < 0x10000_u64
        mods = modules
        return false if mods.empty?
        !mods.any? { |m| m.contains?(address) }
      end

      # Scans standard object registers (e.g. RCX, RDI, RSI, RBX) to detect objects holding stale vtable pointers
      # pointing outside currently mapped module boundaries (frequent during dynamic plugin / GDExtension hot reloading).
      def find_stale_vtables(
        registers_to_scan : Array(String) = ["rcx", "rdi", "rsi", "rbx"],
        vtable_offset : Int32 = 0,
      ) : Array(NamedTuple(register: String, object_address: UInt64, vtable: UInt64, reason: String))
        results = [] of NamedTuple(register: String, object_address: UInt64, vtable: UInt64, reason: String)
        mods = modules
        return results if mods.empty?

        registers_to_scan.each do |reg|
          val_s = @client.cmd("?v #{reg}").strip
          if obj_addr = AddressUtils.to_u64?(val_s)
            if obj_addr > 0x10000_u64
              begin
                vtable_ptr = @client.memory.read_u64(obj_addr + vtable_offset)
                if vtable_ptr > 0x10000_u64 && !mods.any? { |m| m.contains?(vtable_ptr) }
                  results << {
                    register:       reg,
                    object_address: obj_addr,
                    vtable:         vtable_ptr,
                    reason:         "VTable 0x#{vtable_ptr.to_s(16)} points outside all #{mods.size} mapped process modules (stale hot-reload pointer)",
                  }
                end
              rescue
              end
            end
          end
        end

        results
      end

      private def group_maps_by_module(all_maps : Array(Model::MemoryMap)) : Array(Model::ModuleInfo)
        named_maps = all_maps.reject { |m| m.name.empty? || m.name.starts_with?('[') || m.name == "null" }
        return [] of Model::ModuleInfo if named_maps.empty?

        grouped = Hash(String, Array(Model::MemoryMap)).new
        named_maps.each do |m|
          base_key = m.name.gsub('\\', '/').split('/').reject(&.empty?).last? || m.name
          grouped[base_key] ||= Array(Model::MemoryMap).new
          grouped[base_key] << m
        end

        modules_list = [] of Model::ModuleInfo
        grouped.each do |mod_name, reg_list|
          base_addr = reg_list.min_of(&.addr)
          end_addr = reg_list.max_of(&.addr_end)
          full_path = reg_list.first.name
          mod = Model::ModuleInfo.new(
            name: mod_name,
            base_address: base_addr,
            end_address: end_addr,
            size: end_addr > base_addr ? end_addr - base_addr : 0_u64,
            path: full_path,
            regions: reg_list
          )
          modules_list << mod
        end
        modules_list.sort_by(&.base_address)
      end

      # Returns active threads in the process (dptj).
      def threads : Array(Model::Thread)
        @client.cmdj("dptj", as: Array(Model::Thread))
      rescue
        [] of Model::Thread
      end

      # Returns the currently selected thread in the debugger.
      def current_thread : Model::Thread?
        threads.find(&.selected?)
      end

      # Returns the currently active thread ID (dpt.).
      def current_thread_id : Int32?
        res = @client.cmd("dpt.").strip
        res.to_i?
      end

      # Attaches or switches focus to a specific thread ID (dpt=<tid>).
      def select_thread(tid : Int32) : self
        @client.cmd("dpt=#{tid}")
        self
      end

      # Returns a list of attachable / running system processes (dplj).
      def attachable_processes : Array(Model::ProcessInfo)
        @client.cmdj("dplj", as: Array(Model::ProcessInfo))
      rescue
        [] of Model::ProcessInfo
      end

      # Returns the path to the executable of the debugged process (dpe).
      def executable_path : String
        @client.cmd("dpe").strip
      end

      # Reads `count` 64-bit words directly from the current Stack Pointer (SP).
      def stack_words(count : Int32 = 8) : Array(UInt64)
        sp_addr = registers.sp
        return [] of UInt64 if sp_addr == 0_u64
        @client.memory.read_pointer_array(sp_addr, count)
      end

      # Changes memory page protection permissions at target address (dmp <addr> <size> <perms>).
      def protect_memory(target : Address, size : Int32, perms : String) : self
        @client.cmd("dmp #{addr_s(target)} #{size} #{perms}")
        self
      end

      # Allocates a memory region of the given size in the debugged process (dm <addr> <size>).
      def allocate_memory(size : Int32, address : Address? = nil) : self
        addr_part = address ? addr_s(address) : "-1"
        @client.cmd("dm #{addr_part} #{size}")
        self
      end

      # Deallocates a memory region at the given address in the debugged process (dm- <addr>).
      def deallocate_memory(target : Address) : self
        @client.cmd("dm- #{addr_s(target)}")
        self
      end

      # Dumps a debug memory region to a file on disk (dmd).
      def dump_memory_region(path : String) : self
        @client.cmd("dmd #{path}")
        self
      end

      # Attaches to a running process by PID.
      def attach(pid : Int32) : self
        @client.cmd("dp= #{pid}")
        self
      end

      # Detaches from current process.
      def detach : self
        @client.cmd("dp-")
        self
      end

      # Sends SIGKILL or terminates the debugged process.
      def kill : self
        @client.cmd("dk 9")
        self
      end

      # Returns current process ID if debugging.
      def pid : Int32?
        res = @client.cmd("dp").strip
        res.to_i?
      end

      # Returns debugger execution status text.
      def status : String
        @client.cmd("d?").strip
      end

      # Checks if the debugged process is currently active/attached.
      def running? : Bool
        pid != nil
      end

      # Returns a memory classifier configured with the currently loaded memory maps.
      def memory_classifier : Cradare2::Analysis::MemoryClassifier
        Cradare2::Analysis::MemoryClassifier.new(maps)
      end

      # Classifies an arbitrary pointer against the debugged process memory maps.
      def classify_memory(address : UInt64) : Cradare2::Analysis::ClassifiedAddress
        memory_classifier.classify(address)
      end

      # Performs deep structural analysis on current CPU registers and memory boundaries.
      def analyze_registers(regs : Model::Registers? = nil) : Cradare2::Analysis::RegisterAnalysis
        active_regs = regs || registers
        memory_classifier.analyze(active_regs)
      end

      # Generates a structured crash diagnosis with root-cause pattern analysis and remediation steps.
      def diagnose_crash(
        regs : Model::Registers? = nil,
        bt : Array(Model::StackFrame)? = nil,
      ) : Model::CrashDiagnosis
        active_regs = regs || registers
        active_bt = bt || backtrace
        reg_analysis = analyze_registers(active_regs)
        pc = active_regs.pc
        probable_cause = reg_analysis.probable_cause

        # Nearest symbol
        fn_sym : String? = nil
        begin
          res = @client.cmd("fd @ 0x#{pc.to_s(16)}").strip
          fn_sym = Util::Demangler.demangle(res, @client.transport) unless res.empty?
        rescue
        end

        # Faulting instruction
        faulting_instr : Model::Instruction? = nil
        begin
          instrs = @client.disasm.instructions(1, at: pc)
          faulting_instr = instrs.first?
        rescue
        end

        # Recommendations based on cause
        recs = [] of String
        case probable_cause
        when :null_dereference
          recs << "Null pointer dereference: verify pointer is non-null before member access"
          recs << "In game engines (Godot/Lapis), check #alive? or #check_alive! on entity references"
        when :null_branch
          recs << "Execution diverted to null/low memory address (corrupted vtable or null function pointer)"
        when :wild_jump
          recs << "Instruction pointer jumped to unmapped memory; check stack integrity or function pointer corruption"
        when :stack_corruption
          recs << "Stack pointer corrupted or stack overflow detected; check for infinite recursion or massive stack allocations"
        when :access_violation
          recs << "Access violation: attempt to read/write unmapped or protected memory"
        end

        # Check for stale vtables across hot-reloaded modules
        stale = find_stale_vtables rescue [] of NamedTuple(register: String, object_address: UInt64, vtable: UInt64, reason: String)
        unless stale.empty?
          recs << "Stale vtable pointer detected: #{stale.first[:reason]}"
        end

        Model::CrashDiagnosis.new(
          reason: "Native execution fault at 0x#{pc.to_s(16)}",
          probable_cause: probable_cause,
          faulting_address: pc,
          faulting_instruction: faulting_instr,
          faulting_symbol: fn_sym,
          registers: reg_analysis,
          backtrace: active_bt,
          recommendations: recs
        )
      end

      # Generates a detailed, demangled native crash diagnostic report.
      # Includes crash instruction pointer, active function, faulting memory region,
      # registers dump, and demangled call stack.
      def crash_report(
        regs : Model::Registers? = nil,
        bt : Array(Model::StackFrame)? = nil,
      ) : String
        active_regs = regs || registers
        active_bt = bt || backtrace
        pc = active_regs.pc

        io = IO::Memory.new
        io.puts "=== Native Crash Diagnostic Report ==="
        io.puts "Crash PC (Instruction Pointer): 0x#{pc.to_s(16)}"
        io.puts "Stack Pointer (SP):             0x#{active_regs.sp.to_s(16)}"
        io.puts "Base/Frame Pointer (BP):        0x#{active_regs.bp.to_s(16)}"
        io.puts

        # Find nearest symbol or function at PC
        fn_name = "unknown"
        begin
          res = @client.cmd("fd @ 0x#{pc.to_s(16)}").strip
          fn_name = res unless res.empty?
        rescue
        end
        io.puts "Active Function: #{Util::Demangler.demangle(fn_name, @client.transport)}"

        # Identify memory map/region containing PC
        matching_map = maps.find { |m| m.contains?(pc) }
        if matching_map
          io.puts "Faulting Region: #{matching_map.name} (0x#{matching_map.addr.to_s(16)} - 0x#{matching_map.addr_end.to_s(16)}, #{matching_map.perm})"
        else
          io.puts "Faulting Region: UNMAPPED MEMORY (Possible Null Pointer Dereference or Wild Branch!)"
        end

        # Registers dump
        io.puts "\nRegisters:"
        if @client.info.bits == 64
          io.puts "  RAX: 0x#{active_regs.rax.to_s(16)}  RBX: 0x#{active_regs.rbx.to_s(16)}  RCX: 0x#{active_regs.rcx.to_s(16)}"
          io.puts "  RDX: 0x#{active_regs.rdx.to_s(16)}  RSI: 0x#{active_regs.rsi.to_s(16)}  RDI: 0x#{active_regs.rdi.to_s(16)}"
          io.puts "  R8:  0x#{active_regs.r8.to_s(16)}   R9:  0x#{active_regs.r9.to_s(16)}   R10: 0x#{active_regs.r10.to_s(16)}"
        else
          io.puts "  EAX: 0x#{active_regs.eax.to_s(16)}  EBX: 0x#{active_regs.ebx.to_s(16)}  ECX: 0x#{active_regs.ecx.to_s(16)}"
          io.puts "  EDX: 0x#{active_regs.edx.to_s(16)}  ESI: 0x#{active_regs.esi.to_s(16)}  EDI: 0x#{active_regs.edi.to_s(16)}"
        end

        # Backtrace
        io.puts "\nCall Stack (Demangled):"
        if active_bt.empty?
          io.puts "  (No stack frames captured)"
        else
          active_bt.each_with_index do |frame, idx|
            demangled = Util::Demangler.demangle(frame.function, @client.transport)
            io.puts "  ##{idx} 0x#{frame.pc.to_s(16)} in #{demangled}"
          end
        end

        io.to_s
      end
    end
  end
end
