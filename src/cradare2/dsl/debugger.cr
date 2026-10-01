require "../models/module_info"
require "../models/register"
require "../models/breakpoint"
require "../models/stack_frame"
require "../models/memory_map"
require "../models/thread"
require "../models/crash_diagnosis"
require "../analysis/memory_classifier"
require "../util/demangler"
require "../address"

module Cradare2
  module DSL
    # High-level debugger DSL for controlling execution, breakpoints, registers, memory maps, and crash reports.
    class Debugger
      def initialize(@client : Client)
      end

      private def addr_s(address : UInt64 | Int32 | Int64 | String) : String
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

      # Steps one single machine instruction (ds).
      def step : self
        @client.cmd("ds")
        self
      end

      # Steps over calls or compound instructions (dso).
      def step_over : self
        @client.cmd("dso")
        self
      end

      # Continues execution until reaching the specified target address (dsu).
      def step_until(address : UInt64 | Int32 | Int64 | String) : self
        @client.cmd("dsu #{addr_s(address)}")
        self
      end

      # Sets a software breakpoint at the given address or symbol (db).
      def breakpoint(target : UInt64 | Int32 | Int64 | String) : self
        @client.cmd("db #{addr_s(target)}")
        self
      end

      # Removes a breakpoint at the given address or symbol (db-).
      def remove_breakpoint(target : UInt64 | Int32 | Int64 | String) : self
        @client.cmd("db- #{addr_s(target)}")
        self
      end

      # Removes all breakpoints (db-*).
      def clear_breakpoints : self
        @client.cmd("db-*")
        self
      end

      # Returns list of active breakpoints as typed models.
      def breakpoints : Array(Model::Breakpoint)
        @client.cmdj("dbj", as: Array(Model::Breakpoint))
      rescue
        [] of Model::Breakpoint
      end

      # Returns current CPU registers as a strongly typed `Registers` model.
      def registers : Model::Registers
        @client.cmdj("drj", as: Model::Registers)
      rescue
        Model::Registers.new
      end

      # Sets a register to a specific value (e.g. set_register("rax", 0x1234)).
      def set_register(name : String, value : UInt64) : self
        @client.cmd("dr #{name}=0x#{value.to_s(16)}")
        self
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
        clean_name = module_name.downcase
        matching = modules.find do |m|
          m.name.downcase == clean_name ||
            File.basename(m.name).downcase == clean_name ||
            m.name.downcase.includes?(clean_name)
        end
        matching.try(&.base_address)
      end

      private def group_maps_by_module(all_maps : Array(Model::MemoryMap)) : Array(Model::ModuleInfo)
        named_maps = all_maps.reject { |m| m.name.empty? || m.name.starts_with?('[') || m.name == "null" }
        return [] of Model::ModuleInfo if named_maps.empty?

        grouped = Hash(String, Array(Model::MemoryMap)).new
        named_maps.each do |m|
          base_key = File.basename(m.name)
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
