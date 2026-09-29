require "./spec_helper"

describe "Cradare2 Expanded Features & Analysis" do
  describe Cradare2::Model::Xref do
    it "parses JSON and identifies cross-reference types" do
      json = <<-JSON
      [
        {"from": 5368713216, "to": 5368709120, "type": "CALL", "opcode": "call 0x140001000", "fcn_name": "sym.Player_process"},
        {"from": 5368713300, "ref": 5368715000, "type": "DATA", "opcode": "lea rax, [0x140002000]"},
        {"from": 5368713400, "to": 5368713500, "type": "JMP", "opcode": "jmp 0x140001100"}
      ]
      JSON

      xrefs = Array(Cradare2::Model::Xref).from_json(json)
      xrefs.size.should eq(3)

      xrefs[0].from.should eq(5368713216_u64)
      xrefs[0].to.should eq(5368709120_u64)
      xrefs[0].call?.should be_true
      xrefs[0].data?.should be_false
      xrefs[0].function_name.should eq("sym.Player_process")

      xrefs[1].data?.should be_true
      xrefs[1].to.should eq(5368715000_u64)

      xrefs[2].jump?.should be_true
    end
  end

  describe Cradare2::Model::SecurityInfo do
    it "evaluates security mitigations and calculates security score" do
      bin = Cradare2::Model::BinInfo.from_json(<<-JSON
      {
        "arch": "x86",
        "bits": 64,
        "canary": true,
        "nx": true,
        "pic": true,
        "relocs": true,
        "stripped": false
      }
      JSON
      )

      sec = Cradare2::Model::SecurityInfo.from_bin_info(bin)
      sec.aslr?.should be_true
      sec.dep?.should be_true
      sec.canary.should be_true
      sec.relocs.should be_true
      sec.score.should eq(100)
      sec.secure?.should be_true
      sec.recommendations.should be_empty
    end

    it "flags insecure binaries and emits actionable recommendations" do
      bin = Cradare2::Model::BinInfo.from_json(<<-JSON
      {
        "arch": "x86",
        "bits": 64,
        "canary": false,
        "nx": false,
        "pic": false,
        "relocs": false
      }
      JSON
      )

      sec = Cradare2::Model::SecurityInfo.from_bin_info(bin)
      sec.score.should eq(0)
      sec.secure?.should be_false
      sec.recommendations.size.should eq(4)
      sec.recommendations.any? { |r| r.includes?("ASLR") }.should be_true
      sec.recommendations.any? { |r| r.includes?("DEP/NX") }.should be_true
    end
  end

  describe Cradare2::Analysis::MemoryClassifier do
    maps = [
      Cradare2::Model::MemoryMap.new(0x140000000_u64, 0x140010000_u64, "r-x", "C:\\games\\game.dll"),
      Cradare2::Model::MemoryMap.new(0x7ff810000000_u64, 0x7ff810050000_u64, "r-x", "C:\\Windows\\System32\\ntdll.dll"),
      Cradare2::Model::MemoryMap.new(0x7fff20000000_u64, 0x7fff20050000_u64, "r-x", "/usr/lib/x86_64-linux-gnu/libc.so.6"),
      Cradare2::Model::MemoryMap.new(0x00000045f000_u64, 0x00000045ffff_u64, "rw-", "[stack]"),
      Cradare2::Model::MemoryMap.new(0x0000021b3000_u64, 0x0000021b8000_u64, "rw-", "[heap]"),
    ]
    classifier = Cradare2::Analysis::MemoryClassifier.new(maps)

    it "classifies addresses into architectural regions" do
      # 1. Null / Low page
      c_null = classifier.classify(0x0000000000000028_u64)
      c_null.region_type.should eq(Cradare2::Analysis::MemoryRegionType::NullLow)
      c_null.null_or_low?.should be_true

      # 2. Main Game code
      c_code = classifier.classify(0x140001050_u64)
      c_code.region_type.should eq(Cradare2::Analysis::MemoryRegionType::Code)
      c_code.executable?.should be_true
      c_code.module_name.should eq("game.dll")

      # 3. System CRT / Kernel (Windows)
      c_sys = classifier.classify(0x7ff810001000_u64)
      c_sys.region_type.should eq(Cradare2::Analysis::MemoryRegionType::SystemCRT)
      c_sys.module_name.should eq("ntdll.dll")

      # 4. System CRT (POSIX)
      c_libc = classifier.classify(0x7fff20001000_u64)
      c_libc.region_type.should eq(Cradare2::Analysis::MemoryRegionType::SystemCRT)
      c_libc.module_name.should eq("libc.so.6")

      # 5. Stack
      c_stack = classifier.classify(0x00000045f100_u64)
      c_stack.region_type.should eq(Cradare2::Analysis::MemoryRegionType::Stack)

      # 6. Unmapped memory
      c_unmapped = classifier.classify(0xdeadbeefcafebabe_u64)
      c_unmapped.region_type.should eq(Cradare2::Analysis::MemoryRegionType::Unmapped)
      c_unmapped.unmapped?.should be_true
    end

    it "analyzes registers and classifies crash patterns" do
      regs = Cradare2::Model::Registers.new({
        "rax" => 0x140001000_u64,
        "rcx" => 0x0000000000000018_u64, # Null pointer member offset!
        "rip" => 0x140002500_u64,
        "rsp" => 0x00000045f200_u64,
        "rbp" => 0x00000045f250_u64,
      })

      analysis = classifier.analyze(regs)
      analysis.pc.region_type.should eq(Cradare2::Analysis::MemoryRegionType::Code)
      analysis.sp.region_type.should eq(Cradare2::Analysis::MemoryRegionType::Stack)
      analysis.probable_cause.should eq(:null_dereference)
    end

    it "detects wild jumps to unmapped memory" do
      regs = Cradare2::Model::Registers.new({
        "rax" => 0x1234_u64,
        "rcx" => 0x140001000_u64,
        "rip" => 0xdeadbeef0000_u64, # Unmapped wild jump!
        "rsp" => 0x00000045f200_u64,
        "rbp" => 0x00000045f250_u64,
      })

      analysis = classifier.analyze(regs)
      analysis.probable_cause.should eq(:wild_jump)
    end
  end

  describe "Client high-level methods" do
    it "queries cross-references and security posture" do
      handler = ->(cmd : String) {
        case cmd
        when "axtj @ 0x140001000"
          %([{"from": 5368713216, "to": 5368709120, "type": "CALL", "fcn_name": "sym.Player_process"}])
        when "ij"
          %({"bin": {"arch": "x86", "bits": 64, "pic": true, "nx": true, "canary": true, "relocs": true}})
        else
          ""
        end
      }
      client = Cradare2.mock(handler)
      xrefs = client.xrefs_to(0x140001000_u64)
      xrefs.size.should eq(1)
      xrefs.first.function_name.should eq("sym.Player_process")

      sec = client.security
      sec.aslr?.should be_true
      sec.score.should eq(100)
    end
  end
end
