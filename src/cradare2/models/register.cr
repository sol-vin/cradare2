require "json"

module Cradare2
  module Model
    # Represents CPU registers returned by radare2 `drj`.
    # Provides architecture-agnostic helpers for instruction pointer and stack pointer,
    # as well as named accessors for x86/x64/ARM registers.
    struct Registers
      include JSON::Serializable

      # Captures all key-value registers from the JSON payload
      @[JSON::Field(ignore: true)]
      getter values : Hash(String, UInt64) = Hash(String, UInt64).new

      def initialize(pull : JSON::PullParser)
        @values = Hash(String, UInt64).new
        pull.read_object do |key|
          # Some radare2 versions output hex strings or ints
          case pull.kind
          when .int?
            @values[key] = pull.read_int.to_u64
          when .string?
            str = pull.read_string
            if str.starts_with?("0x") || str.starts_with?("0X")
              @values[key] = str[2..].to_u64(16)
            else
              @values[key] = str.to_u64? || 0_u64
            end
          else
            pull.skip
          end
        end
      end

      # For direct instantiation in tests/mocks
      def initialize(registers : Hash(String, UInt64) = Hash(String, UInt64).new)
        @values = registers
      end

      # Returns all captured registers
      def all_registers : Hash(String, UInt64)
        @values
      end

      # Fetches any register by name (case-insensitive)
      def [](name : String) : UInt64
        @values[name.downcase]? || @values[name]? || 0_u64
      end

      # Safe lookup returning nil if register is absent
      def []?(name : String) : UInt64?
        @values[name.downcase]? || @values[name]?
      end

      # Architecture-neutral Instruction Pointer (RIP on x64, EIP on x86, PC on ARM)
      def pc : UInt64
        self["rip"]? || self["eip"]? || self["pc"]? || 0_u64
      end

      # Architecture-neutral Stack Pointer (RSP on x64, ESP on x86, SP on ARM)
      def sp : UInt64
        self["rsp"]? || self["esp"]? || self["sp"]? || 0_u64
      end

      # Architecture-neutral Frame/Base Pointer (RBP on x64, EBP on x86, FP on ARM)
      def bp : UInt64
        self["rbp"]? || self["ebp"]? || self["fp"]? || 0_u64
      end

      # x86_64 registers with 32-bit and ARM fallbacks
      def rip : UInt64
        pc
      end

      def rsp : UInt64
        sp
      end

      def rbp : UInt64
        bp
      end

      def rax : UInt64
        self["rax"]? || self["eax"]? || self["x0"]? || self["r0"]? || 0_u64
      end

      def rbx : UInt64
        self["rbx"]? || self["ebx"]? || self["x1"]? || self["r1"]? || 0_u64
      end

      def rcx : UInt64
        self["rcx"]? || self["ecx"]? || self["x2"]? || self["r2"]? || 0_u64
      end

      def rdx : UInt64
        self["rdx"]? || self["edx"]? || self["x3"]? || self["r3"]? || 0_u64
      end

      def rsi : UInt64
        self["rsi"]? || self["esi"]? || self["x4"]? || self["r4"]? || 0_u64
      end

      def rdi : UInt64
        self["rdi"]? || self["edi"]? || self["x5"]? || self["r5"]? || 0_u64
      end

      def r8 : UInt64
        self["r8"]
      end

      def r9 : UInt64
        self["r9"]
      end

      def r10 : UInt64
        self["r10"]
      end

      def r11 : UInt64
        self["r11"]
      end

      def r12 : UInt64
        self["r12"]
      end

      def r13 : UInt64
        self["r13"]
      end

      def r14 : UInt64
        self["r14"]
      end

      def r15 : UInt64
        self["r15"]
      end

      # x86 (32-bit) registers
      def eip : UInt64
        self["eip"]
      end

      def esp : UInt64
        self["esp"]
      end

      def ebp : UInt64
        self["ebp"]
      end

      def eax : UInt64
        self["eax"]
      end

      def ebx : UInt64
        self["ebx"]
      end

      def ecx : UInt64
        self["ecx"]
      end

      def edx : UInt64
        self["edx"]
      end

      def esi : UInt64
        self["esi"]
      end

      def edi : UInt64
        self["edi"]
      end

      # Flags
      def eflags : UInt64
        self["eflags"]? || self["rflags"]? || 0_u64
      end

      # Carry Flag (CF, bit 0)
      def carry_flag? : Bool
        (eflags & 0x01_u64) != 0
      end

      def cf? : Bool
        carry_flag?
      end

      # Parity Flag (PF, bit 2)
      def parity_flag? : Bool
        (eflags & 0x04_u64) != 0
      end

      def pf? : Bool
        parity_flag?
      end

      # Zero Flag (ZF, bit 6)
      def zero_flag? : Bool
        (eflags & 0x40_u64) != 0
      end

      def zf? : Bool
        zero_flag?
      end

      # Sign Flag (SF, bit 7)
      def sign_flag? : Bool
        (eflags & 0x80_u64) != 0
      end

      def sf? : Bool
        sign_flag?
      end

      # Interrupt Flag (IF, bit 9)
      def interrupt_flag? : Bool
        (eflags & 0x200_u64) != 0
      end

      def if? : Bool
        interrupt_flag?
      end

      # Overflow Flag (OF, bit 11)
      def overflow_flag? : Bool
        (eflags & 0x800_u64) != 0
      end

      def of? : Bool
        overflow_flag?
      end

      # ARM registers
      def lr : UInt64
        self["lr"]? || self["x30"]? || self["r14"]? || 0_u64
      end

      def r0 : UInt64
        self["r0"]? || self["x0"]? || 0_u64
      end

      def r1 : UInt64
        self["r1"]? || self["x1"]? || 0_u64
      end

      def r2 : UInt64
        self["r2"]? || self["x2"]? || 0_u64
      end

      def r3 : UInt64
        self["r3"]? || self["x3"]? || 0_u64
      end

      def r4 : UInt64
        self["r4"]? || self["x4"]? || 0_u64
      end

      def r5 : UInt64
        self["r5"]? || self["x5"]? || 0_u64
      end

      def r6 : UInt64
        self["r6"]? || self["x6"]? || 0_u64
      end

      def r7 : UInt64
        self["r7"]? || self["x7"]? || 0_u64
      end

      # Compares this register snapshot against a baseline, returning a mapping of
      # register_name => {old_value, new_value} for only registers whose values changed.
      def diff(baseline : Registers) : Hash(String, Tuple(UInt64, UInt64))
        changed = Hash(String, Tuple(UInt64, UInt64)).new
        all_keys = (@values.keys + baseline.all_registers.keys).uniq
        all_keys.each do |k|
          val_old = baseline[k]? || 0_u64
          val_new = self[k]? || 0_u64
          if val_old != val_new
            changed[k] = {val_old, val_new}
          end
        end
        changed
      end
    end
  end
end
