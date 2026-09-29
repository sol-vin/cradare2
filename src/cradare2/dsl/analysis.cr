module Cradare2
  module DSL
    # Fluent DSL for binary analysis commands.
    class Analysis
      def initialize(@client : Client)
      end

      # Run complete analysis (aaa)
      def all : self
        @client.cmd("aaa")
        self
      end

      # Run basic analysis (aa)
      def basic : self
        @client.cmd("aa")
        self
      end

      # Analyze function calls (aac)
      def calls : self
        @client.cmd("aac")
        self
      end

      # Analyze all functions (aaf)
      def functions : self
        @client.cmd("aaf")
        self
      end

      # Analyze data and code references (aar)
      def references : self
        @client.cmd("aar")
        self
      end

      # Auto-name functions based on strings and calls (aan)
      def autoname : self
        @client.cmd("aan")
        self
      end

      # Analyze function preludes (aap)
      def preludes : self
        @client.cmd("aap")
        self
      end

      # Analyze code emulation / ESIL (aae)
      def emulate : self
        @client.cmd("aae")
        self
      end

      # Analyze consecutive function blocks (aat)
      def consecutive : self
        @client.cmd("aat")
        self
      end
    end
  end
end
