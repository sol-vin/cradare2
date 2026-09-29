require "json"
require "./binary_info"

module Cradare2
  module Model
    # Comprehensive binary security posture model evaluated from executable headers.
    struct SecurityInfo
      include JSON::Serializable

      getter canary : Bool
      getter nx : Bool
      getter pic : Bool
      getter relocs : Bool
      getter stripped : Bool
      getter crypto : Bool
      getter sanitize : Bool
      getter score : Int32
      getter recommendations : Array(String)

      def initialize(
        @canary : Bool = false,
        @nx : Bool = false,
        @pic : Bool = false,
        @relocs : Bool = false,
        @stripped : Bool = false,
        @crypto : Bool = false,
        @sanitize : Bool = false,
        @score : Int32 = 0,
        @recommendations : Array(String) = [] of String,
      )
      end

      # Computes security metrics from BinInfo
      def self.from_bin_info(bin : BinInfo?) : SecurityInfo
        return new unless bin

        canary = bin.canary == true
        nx = bin.nx == true
        pic = bin.pic == true
        relocs = bin.relocs == true
        stripped = bin.stripped == true
        crypto = bin.crypto == true
        sanitize = bin.sanitize == true

        recs = [] of String
        earned = 0

        if pic
          earned += 30
        else
          recs << "Enable ASLR/PIC (/DYNAMICBASE or -fPIE) to prevent fixed-address exploitation"
        end

        if nx
          earned += 30
        else
          recs << "Enable DEP/NX (/NXCOMPAT or -z noexecstack) to prevent execution of stack memory"
        end

        if canary
          earned += 25
        else
          recs << "Enable Stack Canaries (/GS or -fstack-protector-strong) to detect stack buffer overflows"
        end

        if relocs
          earned += 15
        else
          recs << "Retain base relocations (/FIXED:NO) to enable ASLR address relocation"
        end

        new(
          canary: canary,
          nx: nx,
          pic: pic,
          relocs: relocs,
          stripped: stripped,
          crypto: crypto,
          sanitize: sanitize,
          score: earned,
          recommendations: recs
        )
      end

      def secure? : Bool
        @score >= 85
      end

      def aslr? : Bool
        @pic
      end

      def pic? : Bool
        @pic
      end

      def dep? : Bool
        @nx
      end

      def nx? : Bool
        @nx
      end
    end
  end
end
