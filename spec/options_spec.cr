require "./spec_helper"

describe Cradare2::Options do
  it "initializes with default options" do
    opts = Cradare2::Options.new
    opts.target.should be_nil
    opts.flags.should be_empty
    opts.debug.should be_false
    opts.write.should be_false
    opts.r2_path.should be_nil
    opts.timeout.should be_nil
    opts.source_paths.should be_empty
    opts.path_mappings.should be_empty
    opts.auto_analyze.should be_false
    opts.log_commands.should be_false
  end

  it "builds options using fluent builder" do
    opts = Cradare2::Options.build do |o|
      o.target = "game.dll"
      o.debug = true
      o.write = true
      o.timeout = 5.seconds
      o.source_paths << "./src"
      o.path_mappings["/remote"] = "C:/local"
    end

    opts.target.should eq("game.dll")
    opts.debug.should be_true
    opts.write.should be_true
    opts.timeout.should eq(5.seconds)
    opts.source_paths.should eq(["./src"])
    opts.path_mappings["/remote"].should eq("C:/local")
  end
end
