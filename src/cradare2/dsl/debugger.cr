require "../models/register"
require "../models/breakpoint"
require "../models/stack_frame"
require "../models/memory_map"
require "../models/thread"

module Cradare2
  module DSL
    # High-level debugger DSL for controlling execution, breakpoints, registers, and threads.
    class Debugger
      def initialize(@client : Client)
      end

      private def addr_s(address : UInt64 | String) : String
        address.is_a?(UInt64) ? "0x#{address.to_s(16)}" : address
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
      def step_until(address : UInt64 | String) : self
        @client.cmd("dsu #{addr_s(address)}")
        self
      end

      # Sets a software breakpoint at the given address or symbol (db).
      def breakpoint(target : UInt64 | String) : self
        @client.cmd("db #{addr_s(target)}")
        self
      end

      # Removes a breakpoint at the given address or symbol (db-).
      def remove_breakpoint(target : UInt64 | String) : self
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

      # Returns the loaded memory maps / regions (dmj).
      def maps : Array(Model::MemoryMap)
        @client.cmdj("dmj", as: Array(Model::MemoryMap))
      rescue
        [] of Model::MemoryMap
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

      # Returns current process ID if debugging.
      def pid : Int32?
        res = @client.cmd("dp").strip
        res.to_i?
      end
    end
  end
end
