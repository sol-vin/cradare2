require "./spec_helper"
require "../src/cradare2/lines/line_provider"

# Mock custom provider
class MockCustomLineProvider < Cradare2::Lines::LineProvider
  def initialize
    super("mock_custom")
  end

  def available? : Bool
    true
  end

  def resolve_address(address : UInt64) : Cradare2::Lines::SourceLocation?
    if address == 0x140001000_u64
      Cradare2::Lines::SourceLocation.new("src/player.cr", 42, 5, "def ready")
    else
      nil
    end
  end

  def resolve_instructions(
    instructions : Array(Cradare2::Model::Instruction),
    function_name : String? = nil,
  ) : Hash(UInt64, Cradare2::Lines::SourceLocation)
    res = Hash(UInt64, Cradare2::Lines::SourceLocation).new
    instructions.each do |ins|
      if loc = resolve_address(ins.offset)
        res[ins.offset] = loc
      end
    end
    res
  end
end

describe Cradare2::Lines::LineProvider do
  it "resolves lines using pluggable provider chain" do
    client = SpecFixtures.build_mock_client
    custom_provider = MockCustomLineProvider.new

    map = Cradare2::Lines::SourceMap.new
    resolver = Cradare2::Lines::LineResolver.new(client, map, [custom_provider] of Cradare2::Lines::LineProvider)

    loc = resolver.resolve_address(0x140001000_u64)
    loc.should_not be_nil
    loc.not_nil!.file.should eq("src/player.cr")
    loc.not_nil!.line.should eq(42)

    resolver.resolve_address(0x99999999_u64).should be_nil
  end
end
