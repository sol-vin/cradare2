require "./spec_helper"

describe "Demangler Cache and Bounded Capacity" do
  it "caches demangled results safely and reports cache size" do
    Cradare2::Util::Demangler.clear_cache
    Cradare2::Util::Demangler.cache_size.should eq(0)

    res1 = Cradare2::Util::Demangler.demangle("*Player#ready:Nil")
    res1.should eq("Player#ready:Nil")
    Cradare2::Util::Demangler.cache_size.should eq(1)

    # Cache hit
    res2 = Cradare2::Util::Demangler.demangle("*Player#ready:Nil")
    res2.should eq("Player#ready:Nil")
    Cradare2::Util::Demangler.cache_size.should eq(1)

    Cradare2::Util::Demangler.clear_cache
    Cradare2::Util::Demangler.cache_size.should eq(0)
  end
end

describe "Crystal Runtime Fiber and Hash inspection" do
  it "inspects Crystal Fiber memory layout" do
    handler = ->(cmd : String) {
      case cmd
      when "pxj 4 @ 0x140001000"
        "[10, 0, 0, 0]" # type_id = 10
      when "pxj 1 @ 0x140001004"
        "[1]" # resumable = true
      when "pxj 4 @ 0x140001008"
        "[0, 0, 1, 0]" # stack_size = 65536
      when "pxj 8 @ 0x140001010"
        "[0, 16, 0, 0, 1, 0, 0, 0]" # stack_address = 0x100001000
      else
        ""
      end
    }

    client = Cradare2.mock(handler)
    fiber = client.crystal.read_fiber(0x140001000_u64)
    fiber.address.should eq(0x140001000_u64)
    fiber.type_id.should eq(10)
    fiber.resumable.should be_true
    fiber.stack_size.should eq(65536)
  end

  it "inspects Crystal Hash header memory layout" do
    handler = ->(cmd : String) {
      case cmd
      when "pxj 4 @ 0x140002000"
        "[25, 0, 0, 0]" # type_id = 25
      when "pxj 4 @ 0x140002004"
        "[5, 0, 0, 0]" # size = 5
      when "pxj 4 @ 0x140002008"
        "[16, 0, 0, 0]" # capacity = 16
      else
        ""
      end
    }

    client = Cradare2.mock(handler)
    h = client.crystal.read_hash_header(0x140002000_u64)
    h.address.should eq(0x140002000_u64)
    h.type_id.should eq(25)
    h.size.should eq(5)
    h.capacity.should eq(16)
  end
end
