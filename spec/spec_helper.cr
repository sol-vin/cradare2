require "spec"
require "../src/cradare2"

module SpecFixtures
  SAMPLE_IJ = <<-JSON
  {
    "core": {
      "type": "EXEC",
      "file": "game.dll",
      "size": 65536,
      "format": "pe"
    },
    "bin": {
      "arch": "x86",
      "bits": 64,
      "os": "windows",
      "endian": "little",
      "baddr": 5368709120,
      "pic": true,
      "canary": true,
      "nx": true
    }
  }
  JSON

  SAMPLE_AFLJ = <<-JSON
  [
    {
      "addr": 4198400,
      "name": "sym.main",
      "size": 128,
      "cc": 3,
      "calltype": "cdecl",
      "nargs": 2,
      "nlocals": 4,
      "stackframe": 32,
      "nbbs": 5,
      "signature": "int main(int argc, char **argv)"
    },
    {
      "addr": 4198528,
      "name": "sym.lapis_gdextension_entry",
      "size": 256,
      "cc": 1,
      "calltype": "stdcall",
      "nargs": 3,
      "nlocals": 2,
      "stackframe": 48,
      "nbbs": 8
    }
  ]
  JSON

  SAMPLE_ISJ = <<-JSON
  [
    {
      "name": "sym.main",
      "vaddr": 4198400,
      "paddr": 1024,
      "size": 128,
      "type": "FUNC",
      "bind": "GLOBAL"
    },
    {
      "name": "sym.*MyGame::Player#_ready:Nil",
      "realname": "*MyGame::Player#_ready:Nil",
      "demangled": "MyGame::Player#_ready:Nil",
      "vaddr": 4199000,
      "paddr": 1624,
      "size": 64,
      "type": "FUNC",
      "bind": "GLOBAL"
    },
    {
      "name": "sym.imp.godot_string_new",
      "vaddr": 4200000,
      "size": 0,
      "type": "FUNC",
      "is_imported": true
    }
  ]
  JSON

  SAMPLE_IEJ = <<-JSON
  [
    {
      "name": "lapis_gdextension_entry",
      "vaddr": 4198528,
      "paddr": 1152,
      "size": 256,
      "ordinal": 1
    }
  ]
  JSON

  SAMPLE_IIJ = <<-JSON
  [
    {
      "name": "godot_string_new",
      "vaddr": 4200000,
      "bind": "NONE",
      "type": "FUNC",
      "ordinal": 10
    },
    {
      "name": "godot_variant_call",
      "vaddr": 4200032,
      "bind": "NONE",
      "type": "FUNC",
      "ordinal": 11
    }
  ]
  JSON

  SAMPLE_ISJ_SECTIONS = <<-JSON
  [
    {
      "name": ".text",
      "size": 32768,
      "vsize": 32768,
      "perm": "-r-x",
      "vaddr": 4198400
    },
    {
      "name": ".data",
      "size": 4096,
      "vsize": 8192,
      "perm": "-rw-",
      "vaddr": 4231168
    }
  ]
  JSON

  SAMPLE_IZJ = <<-JSON
  [
    {
      "string": "Godot Engine Initialized",
      "vaddr": 4231200,
      "size": 24,
      "length": 24,
      "section": ".data",
      "type": "ascii"
    },
    {
      "string": "Lapis Runtime Active",
      "vaddr": 4231230,
      "size": 20,
      "length": 20,
      "section": ".data",
      "type": "ascii"
    }
  ]
  JSON

  SAMPLE_DRJ = <<-JSON
  {
    "rax": 4198400,
    "rbx": 100,
    "rcx": 0,
    "rdx": 4231168,
    "rsi": 1000,
    "rdi": 2000,
    "rsp": 140723423000,
    "rbp": 140723423048,
    "rip": 4198450,
    "r8": 1,
    "r9": 2,
    "r10": 3,
    "r11": 4,
    "r12": 5,
    "r13": 6,
    "r14": 7,
    "r15": 8,
    "eflags": 514
  }
  JSON

  SAMPLE_DBTJ = <<-JSON
  [
    {
      "frame": 0,
      "sp": 140723423000,
      "bp": 140723423048,
      "pc": 4198450,
      "fname": "*MyGame::Player#_process:Float64",
      "offset": 4198400
    },
    {
      "frame": 1,
      "sp": 140723423056,
      "bp": 140723423096,
      "pc": 4198560,
      "fname": "lapis_gdextension_entry",
      "offset": 4198528
    }
  ]
  JSON

  SAMPLE_DMJ = <<-JSON
  [
    {
      "name": "game.dll",
      "addr": 4194304,
      "addr_end": 4259840,
      "size": 65536,
      "perm": "-r-x"
    },
    {
      "name": "[stack]",
      "addr": 140723400000,
      "addr_end": 140723500000,
      "size": 100000,
      "perm": "-rw-"
    }
  ]
  JSON

  SAMPLE_PDJ = <<-JSON
  [
    {
      "addr": 4198400,
      "size": 4,
      "opcode": "sub rsp, 0x28",
      "disasm": "sub rsp, 0x28",
      "bytes": "4883ec28",
      "type": "sub"
    },
    {
      "addr": 4198404,
      "size": 5,
      "opcode": "call 0x401200",
      "disasm": "call 0x401200",
      "bytes": "e8f72dfcff",
      "type": "call",
      "jump": 4198912
    }
  ]
  JSON

  # Builds a mock client populated with standard test responses
  def self.build_mock_client : Cradare2::Client
    client = Cradare2.mock
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("ij", SAMPLE_IJ)
    mock.on("aflj", SAMPLE_AFLJ)
    mock.on("isj", SAMPLE_ISJ)
    mock.on("iEj", SAMPLE_IEJ)
    mock.on("iij", SAMPLE_IIJ)
    mock.on("iSj", SAMPLE_ISJ_SECTIONS)
    mock.on("izj", SAMPLE_IZJ)
    mock.on("izzj", SAMPLE_IZJ)
    mock.on("drj", SAMPLE_DRJ)
    mock.on("dbtj", SAMPLE_DBTJ)
    mock.on("dmj", SAMPLE_DMJ)
    mock.on("pdj 2", SAMPLE_PDJ)
    mock.on("pxj 4 @ 0x401000", "[144, 144, 144, 144]")
    mock.on("p8 4 @ 0x401000", "90909090")
    mock.on("s", "4198400")
    client
  end
end
