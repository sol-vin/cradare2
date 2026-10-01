require "./spec_helper"

describe Cradare2::Util::Demangler do
  before_each do
    Cradare2::Util::Demangler.clear_cache
  end

  describe "Crystal symbol demangling & cleaning" do
    it "recognizes and cleans standard Crystal symbols" do
      sym = "*MyGame::Player#_ready:Nil"
      Cradare2::Util::Demangler.is_crystal_symbol?(sym).should be_true
      Cradare2::Util::Demangler.demangle(sym).should eq("MyGame::Player#_ready:Nil")

      sym2 = "~Array(Int32)#push:Array(Int32)"
      Cradare2::Util::Demangler.demangle(sym2).should eq("Array(Int32)#push:Array(Int32)")

      sym3 = "sym.*~String#bytesize"
      Cradare2::Util::Demangler.demangle(sym3).should eq("String#bytesize")

      sym4 = "sym.imp.*~GC_malloc"
      Cradare2::Util::Demangler.demangle(sym4).should eq("GC_malloc")

      sym5 = "*Crystal::main:Int32"
      Cradare2::Util::Demangler.demangle(sym5).should eq("Crystal::main:Int32")
    end

    it "decodes LLVM/MSVC PDB hex-escaped symbols" do
      # _2A. -> *, .3A. -> :, .23. -> #, .3C. -> <, .3E. -> >, .28. -> (, .29. -> )
      pdb_sym1 = "pdb._2A.add.3C.Int32.2C..20.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.is_crystal_symbol?(pdb_sym1).should be_true
      Cradare2::Util::Demangler.demangle(pdb_sym1).should eq("add<Int32, Int32>:Int32")

      # Method with instance hash # and union type
      pdb_sym2 = "pdb._2A.Fiber.3A..3A.ExecutionContext.3A..3A.GlobalQueue.23.unsafe_pop.3F..3A..28.Fiber.20..7C..20.Nil.29."
      Cradare2::Util::Demangler.demangle(pdb_sym2).should eq("Fiber::ExecutionContext::GlobalQueue#unsafe_pop?:(Fiber | Nil)")

      # Method with generic nested Array and pointer return
      pdb_sym3 = "pdb._2A.Array.28.Fiber.3A..3A.Scheduler.29..40.Array.28.T.29..23.init.3C.Int32.3E..3A.Pointer.28.Void.29."
      Cradare2::Util::Demangler.demangle(pdb_sym3).should eq("Array(Fiber::Scheduler)@Array(T)#init<Int32>:Pointer(Void)")
    end

    it "decodes all ASCII punctuation hex escapes" do
      escapes = {
        "_2A." => "*",
        ".3A." => ":",
        ".28." => "(",
        ".29." => ")",
        ".23." => "#",
        ".3C." => "<",
        ".3E." => ">",
        ".2C." => ",",
        ".20." => " ",
        ".7C." => "|",
        ".5B." => "[",
        ".5D." => "]",
        ".3D." => "=",
        ".2B." => "+",
        ".2D." => "-",
        ".2F." => "/",
        ".5C." => "\\",
        ".3F." => "?",
        ".21." => "!",
        ".24." => "$",
        ".25." => "%",
        ".26." => "&",
        ".27." => "'",
        ".3B." => ";",
        ".5E." => "^",
        ".60." => "`",
        ".7B." => "{",
        ".7D." => "}",
        ".7E." => "~",
        ".40." => "@",
      }

      escapes.each do |escape_seq, expected_char|
        test_sym = "pdb.prefix#{escape_seq}suffix"
        decoded = Cradare2::Util::Demangler.decode_pdb_escapes(test_sym)
        decoded.should eq("pdb.prefix#{expected_char}suffix")
      end
    end

    it "decodes compound operator method symbols from PDB" do
      # Operator === (.3D..3D..3D.)
      op_triple_eq = "pdb._2A.UInt8.40.Int.23..3D..3D..3D..3C.Char.3E..3A.Bool"
      Cradare2::Util::Demangler.demangle(op_triple_eq).should eq("UInt8@Int#===<Char>:Bool")

      # Operator == (.3D..3D.)
      op_double_eq = "pdb._2A.String.23..3D..3D..3C.String.3E..3A.Bool"
      Cradare2::Util::Demangler.demangle(op_double_eq).should eq("String#==<String>:Bool")

      # Operator [] (.5B..5D.)
      op_bracket = "pdb._2A.Array.28.Int32.29..23..5B..5D..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(op_bracket).should eq("Array(Int32)#[]<Int32>:Int32")

      # Operator []= (.5B..5D..3D.)
      op_bracket_set = "pdb._2A.Array.28.Int32.29..23..5B..5D..3D..3C.Int32.2C..20.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(op_bracket_set).should eq("Array(Int32)#[]=<Int32, Int32>:Int32")

      # Operator + (.2B.)
      op_plus = "pdb._2A.Int32.23..2B..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(op_plus).should eq("Int32#+<Int32>:Int32")

      # Operator - (.2D.)
      op_minus = "pdb._2A.Int32.23..2D..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(op_minus).should eq("Int32#-<Int32>:Int32")

      # Operator * (_2A.)
      op_mul = "pdb._2A.Int32.23._2A..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(op_mul).should eq("Int32#*<Int32>:Int32")

      # Operator / (.2F.)
      op_div = "pdb._2A.Int32.23..2F..3C.Int32.3E..3A.Float64"
      Cradare2::Util::Demangler.demangle(op_div).should eq("Int32#/<Int32>:Float64")

      # Operator << (.3C..3C.)
      op_shl = "pdb._2A.Array.28.String.29..23..3C..3C..3C.String.3E..3A.Array.28.String.29."
      Cradare2::Util::Demangler.demangle(op_shl).should eq("Array(String)#<<<String>:Array(String)")

      # Operator <=> (.3C..3D..3E.)
      op_cmp = "pdb._2A.Int32.23..3C..3D..3E..3C.Int32.3E..3A.Int32"
      Cradare2::Util::Demangler.demangle(op_cmp).should eq("Int32#<=><Int32>:Int32")
    end

    it "strips all radare2 symbol prefixes cleanly" do
      prefixes = ["sym.imp.", "sym.pdb.", "sym.", "pdb."]
      prefixes.each do |prefix|
        sym = "#{prefix}*Foo::Bar#baz:Nil"
        Cradare2::Util::Demangler.demangle(sym).should eq("Foo::Bar#baz:Nil")
      end
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

    it "caches demangling results and respects clear_cache" do
      sym = "*CacheTest::Class#compute:Int32"
      res = Cradare2::Util::Demangler.demangle(sym)
      res.should eq("CacheTest::Class#compute:Int32")

      # Should return cached value
      Cradare2::Util::Demangler.demangle(sym).should eq("CacheTest::Class#compute:Int32")

      Cradare2::Util::Demangler.clear_cache
      # Re-demangles cleanly after clear
      Cradare2::Util::Demangler.demangle(sym).should eq("CacheTest::Class#compute:Int32")
    end

    it "handles edge case symbols gracefully" do
      # Empty string
      Cradare2::Util::Demangler.demangle("").should eq("")

      # Generic symbol without mangling
      Cradare2::Util::Demangler.demangle("simple_function").should eq("simple_function")

      # Symbol with non-hex dot escapes (should preserve verbatim)
      Cradare2::Util::Demangler.demangle("foo.ZZ.bar").should eq("foo.ZZ.bar")

      # Leading and trailing dots
      Cradare2::Util::Demangler.demangle("...").should eq("...")
    end
  end

  describe "Native symbol recognition" do
    it "recognizes C++ and MSVC mangled symbols" do
      Cradare2::Util::Demangler.is_mangled_native?("_Z3foov").should be_true
      Cradare2::Util::Demangler.is_mangled_native?("?func@@YAHXZ").should be_true
      Cradare2::Util::Demangler.is_mangled_native?("_RNvC").should be_true # Rust v0
      Cradare2::Util::Demangler.is_mangled_native?("main").should be_false
    end

    it "queries r2 for native demangling when transport is provided" do
      handler = ->(cmd : String) {
        if cmd == "?m _Z3foov"
          "foo()"
        else
          ""
        end
      }
      mock_transport = Cradare2::Transport::MockTransport.new(handler)

      res = Cradare2::Util::Demangler.demangle("_Z3foov", mock_transport)
      res.should eq("foo()")
    end
  end
end
