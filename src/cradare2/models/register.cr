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

      # x86_64 registers
      def rip : UInt64; self["rip"]; end
      def rsp : UInt64; self["rsp"]; end
      def rbp : UInt64; self["rbp"]; end
      def rax : UInt64; self["rax"]; end
      def rbx : UInt64; self["rbx"]; end
      def rcx : UInt64; self["rcx"]; end
      def rdx : UInt64; self["rdx"]; end
      def rsi : UInt64; self["rsi"]; end
      def rdi : UInt64; self["rdi"]; end
      def r8  : UInt64; self["r8"];  end
      def r9  : UInt64; self["r9"];  end
      def r10 : UInt64; self["r10"]; end
      def r11 : UInt64; self["r11"]; end
      def r12 : UInt64; self["r12"]; end
      def r13 : UInt64; self["r13"]; end
      def r14 : UInt64; self["r14"]; end
      def r15 : UInt64; self["r15"]; end

      # x86 (32-bit) registers
      def eip : UInt64; self["eip"]; end
      def esp : UInt64; self["esp"]; end
      def ebp : UInt64; self["ebp"]; end
      def eax : UInt64; self["eax"]; end
      def ebx : UInt64; self["ebx"]; end
      def ecx : UInt64; self["ecx"]; end
      def edx : UInt64; self["edx"]; end
      def esi : UInt64; self["esi"]; end
      def edi : UInt64; self["edi"]; end

      # Flags
      def eflags : UInt64; self["eflags"]? || self["rflags"]? || 0_u64; end
    end
  end
end
