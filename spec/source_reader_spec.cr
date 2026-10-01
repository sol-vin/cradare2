require "./spec_helper"

describe Cradare2::Lines::SourceReader do
  describe "in-memory virtual sources" do
    it "registers and reads virtual source lines" do
      reader = Cradare2::Lines::SourceReader.new
      content = <<-CR
      def calculate(a : Int32) : Int32
        x = a * 2
        y = x + 10
        y
      end
      CR

      reader.register_source("calc.cr", content)
      reader.exists?("calc.cr").should be_true

      reader.read_line("calc.cr", 1).should eq("def calculate(a : Int32) : Int32")
      reader.read_line("calc.cr", 2).should eq("  x = a * 2")
      reader.read_line("calc.cr", 3).should eq("  y = x + 10")
      reader.read_line("calc.cr", 4).should eq("  y")
      reader.read_line("calc.cr", 5).should eq("end")
    end

    it "handles line index boundary conditions" do
      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("sample.cr", "line one\nline two\nline three")

      # First line
      reader.read_line("sample.cr", 1).should eq("line one")

      # Last line
      reader.read_line("sample.cr", 3).should eq("line three")

      # Past EOF
      reader.read_line("sample.cr", 4).should be_nil
      reader.read_line("sample.cr", 1000).should be_nil

      # Zero and negative lines
      reader.read_line("sample.cr", 0).should be_nil
      reader.read_line("sample.cr", -1).should be_nil
      reader.read_line("sample.cr", -100).should be_nil
    end

    it "extracts contextual line blocks with read_context" do
      reader = Cradare2::Lines::SourceReader.new
      content = (1..10).map { |i| "line #{i}" }.join("\n")
      reader.register_source("numbers.cr", content)

      # Context around line 5 (before: 2, after: 2) -> lines 3..7
      ctx = reader.read_context("numbers.cr", 5, before: 2, after: 2)
      ctx.size.should eq(5)
      ctx.map { |c| c[:line] }.should eq([3, 4, 5, 6, 7])
      ctx.find { |c| c[:line] == 5 }.not_nil![:current].should be_true
      ctx.find { |c| c[:line] == 3 }.not_nil![:current].should be_false

      # Context clamped at beginning of file
      ctx_start = reader.read_context("numbers.cr", 1, before: 3, after: 2)
      ctx_start.size.should eq(3) # lines 1, 2, 3
      ctx_start.first[:line].should eq(1)

      # Context clamped at end of file
      ctx_end = reader.read_context("numbers.cr", 10, before: 2, after: 5)
      ctx_end.size.should eq(3) # lines 8, 9, 10
      ctx_end.last[:line].should eq(10)

      # Zero context window
      ctx_zero = reader.read_context("numbers.cr", 5, before: 0, after: 0)
      ctx_zero.size.should eq(1)
      ctx_zero.first[:line].should eq(5)
      ctx_zero.first[:text].should eq("line 5")
      ctx_zero.first[:current].should be_true
    end

    it "handles clear_cache correctly" do
      reader = Cradare2::Lines::SourceReader.new
      reader.register_source("temp.cr", "content")
      reader.read_line("temp.cr", 1).should eq("content")

      reader.clear_cache
      reader.read_line("temp.cr", 1).should be_nil
    end

    it "returns nil for non-existent files" do
      reader = Cradare2::Lines::SourceReader.new
      reader.exists?("non_existent_file_xyz_123.cr").should be_false
      reader.read_line("non_existent_file_xyz_123.cr", 1).should be_nil
      reader.read_context("non_existent_file_xyz_123.cr", 1).should be_empty
    end
  end

  describe "disk file reading" do
    it "reads actual source files from disk" do
      reader = Cradare2::Lines::SourceReader.new
      # Read src/cradare2/version.cr
      version_path = File.join("src", "cradare2", "version.cr")
      reader.exists?(version_path).should be_true

      line1 = reader.read_line(version_path, 1)
      line1.should_not be_nil
      line1.not_nil!.should contain("module Cradare2")
    end
  end
end
