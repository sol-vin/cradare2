require "./spec_helper"

describe Cradare2::Lines::LineHelper do
  it "provides access to LineHelper through client.crystal.lines" do
    client = Cradare2.mock
    client.crystal.lines.should be_a(Cradare2::Lines::LineHelper)

    # Block form
    yielded = false
    client.crystal.lines do |lines|
      yielded = true
      lines.should be_a(Cradare2::Lines::LineHelper)
    end
    yielded.should be_true
  end

  it "manages map, resolver, and reader singletons" do
    client = Cradare2.mock
    lines = client.crystal.lines

    lines.map.should be_a(Cradare2::Lines::SourceMap)
    lines.resolver.should be_a(Cradare2::Lines::LineResolver)
    lines.reader.should be_a(Cradare2::Lines::SourceReader)

    # Calling again returns same map instance
    lines.map.should be(lines.map)
  end

  it "resolves and returns location for address via lines.at" do
    clj_json = %([{"file":"src/calc.cr","line":8,"colu":2,"addr":4194350}])
    client = SpecFixtures.build_mock_with_handler do |cmd|
      cmd == "CLj" ? clj_json : ""
    end

    loc = client.crystal.lines.at(4194350_u64)
    loc.should_not be_nil
    loc.not_nil!.file.should eq("src/calc.cr")
    loc.not_nil!.line.should eq(8)
    loc.not_nil!.column.should eq(2)
  end

  it "delegates sync_to_r2 and records commands in client" do
    executed = [] of String
    client = SpecFixtures.build_mock_with_handler do |cmd|
      executed << cmd
      ""
    end

    # Pre-populate map
    client.crystal.lines.map.add(0x401000_u64, "test.cr", 1, 0, "nop", 1, source_text: "x = 1")

    synced_count = client.crystal.lines.sync_to_r2
    synced_count.should eq(1)

    executed.should contain("CL 0x401000 test.cr:1")
    executed.should contain("CC \"test.cr:1 | x = 1\" @ 0x401000")
    executed.should contain("e asm.dwarf=true")
  end

  it "generates interleaved view for function" do
    client = SpecFixtures.build_mock_with_handler do |cmd|
      ""
    end

    # Register virtual source file
    client.crystal.lines.reader.register_source("hello.cr", "puts \"Hello\"\nexit")
    client.crystal.lines.map.add(0x1000_u64, "hello.cr", 1, 0, "call puts", 5, "e800000000", "main")
    client.crystal.lines.map.add(0x1005_u64, "hello.cr", 2, 0, "ret", 1, "c3", "main")

    view = client.crystal.lines.interleaved("main")
    view.should contain("File: hello.cr")
    view.should contain("puts \"Hello\"")
    view.should contain("call puts")
    view.should contain("ret")
  end

  it "clears and reloads source map on reload" do
    client = SpecFixtures.build_mock_with_handler do |cmd|
      ""
    end

    client.crystal.lines.map.add(0x1000_u64, "old.cr", 1, 0, "nop", 1)
    client.crystal.lines.map.size.should eq(1)

    reloaded_map = client.crystal.lines.reload
    # Since mock client has no functions/CLj, reloaded map will be empty
    reloaded_map.size.should eq(0)
  end
end
