require "./spec_helper"

describe Cradare2::Util::Demangler do
  it "recognizes and cleans Crystal symbols" do
    sym = "*MyGame::Player#_ready:Nil"
    Cradare2::Util::Demangler.is_crystal_symbol?(sym).should be_true
    Cradare2::Util::Demangler.demangle(sym).should eq("MyGame::Player#_ready:Nil")

    sym2 = "~Array(Int32)#push:Array(Int32)"
    Cradare2::Util::Demangler.demangle(sym2).should eq("Array(Int32)#push:Array(Int32)")
  end

  it "recognizes C++ and MSVC mangled symbols" do
    Cradare2::Util::Demangler.is_mangled_native?("_ZN5Godot6StringC1Ev").should be_true
    Cradare2::Util::Demangler.is_mangled_native?("?my_func@@YAHXZ").should be_true
    Cradare2::Util::Demangler.is_mangled_native?("main").should be_false
  end

  it "demangles via radare2 client and caches result" do
    client = Cradare2.mock
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("?m _ZN5Godot6StringC1Ev", "Godot::String::String()")

    res = Cradare2::Util::Demangler.demangle("_ZN5Godot6StringC1Ev", client.transport)
    res.should eq("Godot::String::String()")

    # Second call should hit the cache without calling transport
    mock.reset
    res_cached = Cradare2::Util::Demangler.demangle("_ZN5Godot6StringC1Ev", client.transport)
    res_cached.should eq("Godot::String::String()")
    mock.history.should be_empty
  end
end
