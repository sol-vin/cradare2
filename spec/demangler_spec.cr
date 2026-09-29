require "./spec_helper"

describe Cradare2::Util::Demangler do
  before_each do
    Cradare2::Util::Demangler.clear_cache
  end

  describe "Crystal symbol demangling & cleaning" do
    it "recognizes and cleans Crystal symbols" do
      sym = "*MyGame::Player#_ready:Nil"
      Cradare2::Util::Demangler.is_crystal_symbol?(sym).should be_true
      Cradare2::Util::Demangler.demangle(sym).should eq("MyGame::Player#_ready:Nil")

      sym2 = "~Array(Int32)#push:Array(Int32)"
      Cradare2::Util::Demangler.demangle(sym2).should eq("Array(Int32)#push:Array(Int32)")

      sym3 = "sym.*~String#bytesize"
      Cradare2::Util::Demangler.demangle(sym3).should eq("String#bytesize")

      sym4 = "sym.imp.*~GC_malloc"
      Cradare2::Util::Demangler.demangle(sym4).should eq("GC_malloc")
    end

    it "parses instance and class methods with parse_crystal_method" do
      # Instance method with return type
      res1 = Cradare2::Util::Demangler.parse_crystal_method("*Foo#bar:Int32")
      res1.should_not be_nil
      res1.not_nil![0].should eq("Foo")
      res1.not_nil![1].should eq("bar:Int32")
      res1.not_nil![2].should be_true

      # Complex generic class with nested generics
      res2 = Cradare2::Util::Demangler.parse_crystal_method("*~Hash(String, Array(Int32))#[]?:Array(Int32)?")
      res2.should_not be_nil
      res2.not_nil![0].should eq("Hash(String, Array(Int32))")
      res2.not_nil![1].should eq("[]?:Array(Int32)?")
      res2.not_nil![2].should be_true

      # Inherited method with @ marker
      res3 = Cradare2::Util::Demangler.parse_crystal_method("sym.*ChildClass@ParentClass#process:Nil")
      res3.should_not be_nil
      res3.not_nil![0].should eq("ChildClass")
      res3.not_nil![1].should eq("process:Nil")
      res3.not_nil![2].should be_true

      # Class/module static method with ::
      res4 = Cradare2::Util::Demangler.parse_crystal_method("*MyModule::Factory::create:MyModule::Object")
      res4.should_not be_nil
      res4.not_nil![0].should eq("MyModule::Factory")
      res4.not_nil![1].should eq("create:MyModule::Object")
      res4.not_nil![2].should be_false

      # Plain C function (no # or ::)
      res5 = Cradare2::Util::Demangler.parse_crystal_method("main")
      res5.should be_nil
    end
  end

  describe "Native symbol recognition" do
    it "recognizes C++ and MSVC mangled symbols" do
      Cradare2::Util::Demangler.is_mangled_native?("_ZN5Engine6StringC1Ev").should be_true
      Cradare2::Util::Demangler.is_mangled_native?("?my_func@@YAHXZ").should be_true
      Cradare2::Util::Demangler.is_mangled_native?("_R5alloc").should be_true
      Cradare2::Util::Demangler.is_mangled_native?("main").should be_false
    end

    it "demangles via radare2 client and caches result" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("?m _ZN5Engine6StringC1Ev", "Engine::String::String()")

      res = Cradare2::Util::Demangler.demangle("_ZN5Engine6StringC1Ev", client.transport)
      res.should eq("Engine::String::String()")

      # Second call should hit the cache without calling transport
      mock.reset
      res_cached = Cradare2::Util::Demangler.demangle("_ZN5Engine6StringC1Ev", client.transport)
      res_cached.should eq("Engine::String::String()")
      mock.history.should be_empty

      # After clearing cache, it should query transport again
      Cradare2::Util::Demangler.clear_cache
      mock.on("?m _ZN5Engine6StringC1Ev", "Engine::String::String()")
      res_after_clear = Cradare2::Util::Demangler.demangle("_ZN5Engine6StringC1Ev", client.transport)
      res_after_clear.should eq("Engine::String::String()")
      mock.history.should contain("?m _ZN5Engine6StringC1Ev")
    end
  end
end
