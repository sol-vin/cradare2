require "./spec_helper"

describe "SourceReader Path Remapping" do
  it "remaps remote build prefixes to local source files" do
    reader = Cradare2::Lines::SourceReader.new
    reader.register_source("C:/local/src/main.cr", "puts 123")

    reader.map_path("/github/workspace/src", "C:/local/src")

    reader.exists?("/github/workspace/src/main.cr").should be_true
    reader.read_line("/github/workspace/src/main.cr", 1).should eq("puts 123")
  end

  it "clears mappings when requested" do
    reader = Cradare2::Lines::SourceReader.new
    reader.map_path("/remote", "/local")
    reader.path_mappings.size.should eq(1)

    reader.clear_mappings
    reader.path_mappings.should be_empty
  end
end
