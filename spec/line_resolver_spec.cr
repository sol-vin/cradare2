require "./spec_helper"

describe Cradare2::Lines::LineResolver do
  describe "querying radare2 CLj line table" do
    it "parses CLj JSON output into SourceLocation mappings" do
      clj_json = <<-JSON
      [
        {"file":"src/main.cr","line":10,"colu":5,"addr":4198400},
        {"file":"src/main.cr","line":11,"colu":2,"addr":4198408},
        {"file":"src/player.cr","line":25,"colu":0,"addr":4199000}
      ]
      JSON

      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        cmd == "CLj" ? clj_json : ""
      end

      resolver = Cradare2::Lines::LineResolver.new(mock_client)
      lines = resolver.query_r2_codelines

      lines.size.should eq(3)
      lines[4198400_u64].file.should eq("src/main.cr")
      lines[4198400_u64].line.should eq(10)
      lines[4198400_u64].column.should eq(5)

      lines[4199000_u64].file.should eq("src/player.cr")
      lines[4199000_u64].line.should eq(25)
    end

    it "handles empty or invalid CLj output gracefully" do
      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        ""
      end

      resolver = Cradare2::Lines::LineResolver.new(mock_client)
      resolver.query_r2_codelines.should be_empty
    end
  end

  describe "file, line, column string parsing" do
    it "resolves instructions using CLj lines" do
      clj_json = %([{"file":"app.cr","line":5,"colu":1,"addr":4194304}])
      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        cmd == "CLj" ? clj_json : ""
      end

      resolver = Cradare2::Lines::LineResolver.new(mock_client)
      ins = Cradare2::Model::Instruction.new(
        offset: 4194304_u64,
        size: 3,
        opcode: "mov rax, rcx",
        bytes: "4889c8"
      )

      resolver.resolve_instructions([ins], "main")
      map = resolver.map
      map.size.should eq(1)

      loc = map.find_by_address(4194304_u64)
      loc.should_not be_nil
      loc.not_nil!.file.should eq("app.cr")
      loc.not_nil!.line.should eq(5)
    end
  end

  describe "binary path discovery" do
    it "resolves target binary path from core info" do
      info_json = %({"core":{"file":"C:\\\\bin\\\\app.exe"},"bin":{"arch":"x86"}})
      mock_client = SpecFixtures.build_mock_with_handler do |cmd|
        cmd == "ij" ? info_json : ""
      end

      resolver = Cradare2::Lines::LineResolver.new(mock_client)
      # In mock environment File.file?("C:\\bin\\app.exe") is false, returns nil safely
      resolver.resolve_target_binary_path.should be_nil
    end
  end
end
