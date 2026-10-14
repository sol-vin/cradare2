require "./spec_helper"

# Helper to pack a sequence of {lower_u32, upper_u32} pairs into little-endian VU1 micro-memory bytes
private def pack_vu1_words(pairs : Array(Tuple(UInt32, UInt32))) : Bytes
  bytes = Bytes.new(pairs.size * 8)
  pairs.each_with_index do |(lower, upper), i|
    IO::ByteFormat::LittleEndian.encode(lower, bytes[i * 8, 4])
    IO::ByteFormat::LittleEndian.encode(upper, bytes[i * 8 + 4, 4])
  end
  bytes
end

# Helper to format bytes as a JSON byte array string for r2 `pxj` mock responses
private def bytes_to_pxj(bytes : Bytes) : String
  "[" + bytes.map(&.to_s).join(", ") + "]"
end

describe Cradare2::PS2::VUProfiler do
  describe "Hardware Memory Map & Register Constants" do
    it "exposes VU0/VU1 micro-memory (0x11008000) and data-memory (0x1100C000) constants" do
      Cradare2::PS2::Registers::VU0_MICRO_MEM.should eq(0x11000000_u64)
      Cradare2::PS2::Registers::VU0_DATA_MEM.should eq(0x11004000_u64)
      Cradare2::PS2::Registers::VU1_MICRO_MEM.should eq(0x11008000_u64)
      Cradare2::PS2::Registers::VU1_MICRO_MEM_SIZE.should eq(0x4000_u64)
      Cradare2::PS2::Registers::VU1_DATA_MEM.should eq(0x1100C000_u64)
      Cradare2::PS2::Registers::VU1_DATA_MEM_SIZE.should eq(0x4000_u64)
      Cradare2::PS2::Registers::VIF1_STAT.should eq(0x10003C00_u64)
      Cradare2::PS2::Registers::VIF1_TOP.should eq(0x10003CE0_u64)
      Cradare2::PS2::Registers::VIF1_TOPS.should eq(0x10003CC0_u64)
      Cradare2::PS2::Registers::DMAC_CHCR1.should eq(0x10009000_u64)
      Cradare2::PS2::Registers::EE_T0_COUNT.should eq(0x10000000_u64)
      Cradare2::PS2::Registers::NTSC_VU1_CYCLES.should eq(2_457_600_u64)
      Cradare2::PS2::Registers::PAL_VU1_CYCLES.should eq(2_949_120_u64)
    end
  end

  describe "64-Bit Dual-Issue Micro-Instruction Decoding" do
    it "decodes canonical NOP | NOP and [E]-bit termination words" do
      inst = Cradare2::PS2::VUProfiler.decode_instruction(0x8000033C_u32, 0x000002FF_u32, 0_u32)
      inst.pc.should eq(0_u32)
      inst.address.should eq(0x11008000_u64)
      inst.upper_nop?.should be_true
      inst.lower_nop?.should be_true
      inst.dual_issued?.should be_false
      inst.e_bit.should be_false

      end_inst = Cradare2::PS2::VUProfiler.decode_instruction(0x8000033C_u32, 0x400002FF_u32, 4_u32)
      end_inst.pc.should eq(4_u32)
      end_inst.address.should eq(0x11008020_u64)
      end_inst.e_bit.should be_true
      end_inst.upper_mnemonic.should eq("NOP[E]")
    end

    it "decodes LOI (I-bit) 32-bit IEEE 754 float immediate in Lower slot" do
      float_bits = 2.5_f32.unsafe_as(UInt32)
      upper_with_i = 0x800002FF_u32
      inst = Cradare2::PS2::VUProfiler.decode_instruction(float_bits, upper_with_i, 1_u32)

      inst.i_bit.should be_true
      inst.lower_op.should eq("LOI")
      inst.immediate_float.should eq(2.5_f32)
      inst.lower_mnemonic.should contain("LOI 2.5")
    end

    it "decodes dual-issue Upper FMAC and Lower Load/Store/IALU/FDIV/XGKICK instructions" do
      # Upper: MULAx.xyzw ACC, vf01, vf05 -> dest=0xF (<<21), ft=5 (<<16), fs=1 (<<11), op11=0x1BC (MULABC x)
      upper_mulax = (0xF_u32 << 21) | (5_u32 << 16) | (1_u32 << 11) | 0x1BC_u32
      # Lower: IADDIU vi02, vi00, 16 -> top7=0x08 (<<25), it=2 (<<16), is=0 (<<11), imm=16
      lower_iaddiu = (0x08_u32 << 25) | (2_u32 << 16) | 16_u32

      inst = Cradare2::PS2::VUProfiler.decode_instruction(lower_iaddiu, upper_mulax, 0_u32)
      inst.dual_issued?.should be_true
      inst.upper_op.should eq("MULABC")
      inst.writes_acc.should be_true
      inst.upper_mnemonic.should eq("MULAx.xyzw ACC, vf01, vf05")
      inst.lower_op.should eq("IADDIU")
      inst.lower_vi_dest.should eq(2_u8)
      inst.lower_mnemonic.should eq("IADDIU vi02, vi00, 16")
    end
  end

  describe "Pipeline Stall & Register Hazard Analysis" do
    it "detects 4-cycle FMAC RAW interlock stalls and calculates exact stall cycles" do
      # PC 0: ADD.xyzw vf01, vf02, vf03 | NOP
      u_add = (0xF_u32 << 21) | (3_u32 << 16) | (2_u32 << 11) | (1_u32 << 6) | 0x28_u32
      # PC 1: MUL.xyzw vf04, vf01, vf05 | NOP (reads vf01 at delta=1 -> 3 stall cycles!)
      u_mul = (0xF_u32 << 21) | (5_u32 << 16) | (1_u32 << 11) | (4_u32 << 6) | 0x2A_u32
      # PC 2: NOP[E] | NOP
      u_end = 0x400002FF_u32
      # PC 3: NOP | NOP
      u_nop = 0x000002FF_u32
      l_nop = 0x8000033C_u32

      micro_bytes = pack_vu1_words([
        {l_nop, u_add},
        {l_nop, u_mul},
        {l_nop, u_end},
        {l_nop, u_nop},
      ])

      profiler = Cradare2::PS2::VUProfiler.from_bytes(micro_bytes)
      report = profiler.profile

      report.instruction_count.should eq(4)
      report.base_cycles.should eq(4)
      report.stall_cycles.should eq(3)
      report.total_cycles.should eq(7)
      report.ee_equivalent_cycles.should eq(14)
      report.terminated_by_e_bit.should be_true
      report.hazards.size.should eq(1)
      report.hazards[0].hazard_type.should eq(Cradare2::PS2::HazardType::FmacRaw)
      report.hazards[0].pc.should eq(1_u32)
      report.hazards[0].producer_pc.should eq(0_u32)
      report.hazards[0].stall_cycles.should eq(3)
      report.hazards[0].register.should eq("vf01.xyzw")
    end

    it "detects LQ -> FMAC load-to-use stall, FDIV WAITQ stall, VI -> Branch hazard, and XGKICK stall" do
      u_nop = 0x000002FF_u32
      l_nop = 0x8000033C_u32

      # PC 0: NOP | LQ.xyzw vf02, 0(vi01)
      l_lq = (0x00_u32 << 25) | (0xF_u32 << 21) | (2_u32 << 16) | (1_u32 << 11)
      # PC 1: ADD.xyzw vf03, vf02, vf00 | DIV Q, vf00.w, vf01.x (reads vf02 1 cycle after LQ -> 3 cycle LoadUse stall; starts 7-cycle DIV)
      u_add = (0xF_u32 << 21) | (0_u32 << 16) | (2_u32 << 11) | (3_u32 << 6) | 0x28_u32
      l_div = 0x800003BC_u32 | (0_u32 << 23) | (3_u32 << 21) | (1_u32 << 16) | (0_u32 << 11)
      # PC 2: NOP | WAITQ (1 cycle after DIV -> 6 cycle FdivWait stall)
      l_waitq = 0x800003BF_u32
      # PC 3: NOP | IADDI vi01, vi01, -1
      l_iaddi = 0x80000032_u32 | (1_u32 << 16) | (1_u32 << 11) | ((0x1F_u32) << 6)
      # PC 4: NOP | IBNE vi01, vi00, -4 (reads vi01 1 cycle after IADDI -> IaluBranch error!)
      l_ibne = (0x29_u32 << 25) | (0_u32 << 16) | (1_u32 << 11) | ((-4) & 0x7FF).to_u32
      # PC 5: NOP | XGKICK vi02
      l_kick = 0x800006FC_u32 | (2_u32 << 11)
      # PC 6: NOP | XGKICK vi02 (1 cycle after previous XGKICK -> 3 cycle XgkickStall)
      micro_bytes = pack_vu1_words([
        {l_lq, u_nop},
        {l_div, u_add},
        {l_waitq, u_nop},
        {l_iaddi, u_nop},
        {l_ibne, u_nop},
        {l_kick, u_nop},
        {l_kick, 0x400002FF_u32},
        {l_nop, u_nop},
      ])

      profiler = Cradare2::PS2::VUProfiler.from_bytes(micro_bytes)
      report = profiler.profile

      types = report.hazards.map(&.hazard_type)
      types.should contain(Cradare2::PS2::HazardType::LoadUse)
      types.should contain(Cradare2::PS2::HazardType::FdivWait)
      types.should contain(Cradare2::PS2::HazardType::IaluBranch)
      types.should contain(Cradare2::PS2::HazardType::XgkickStall)
      report.xgkick_count.should eq(2)
      report.has_errors?.should be_true
    end

    it "detects same-cycle VF write conflicts while allowing disjoint component masks (.xy vs .zw)" do
      # Conflict: ADD.xyzw vf03, vf01, vf02 | LQ.xyzw vf03, 0(vi01)
      u_add_xyzw = (0xF_u32 << 21) | (2_u32 << 16) | (1_u32 << 11) | (3_u32 << 6) | 0x28_u32
      l_lq_xyzw = (0x00_u32 << 25) | (0xF_u32 << 21) | (3_u32 << 16) | (1_u32 << 11)
      conflict_inst = Cradare2::PS2::VUProfiler.decode_instruction(l_lq_xyzw, u_add_xyzw, 0_u32)

      prof = Cradare2::PS2::VUProfiler.new
      hazards = prof.analyze_hazards([conflict_inst])
      hazards.size.should eq(1)
      hazards[0].hazard_type.should eq(Cradare2::PS2::HazardType::SameCycleVfWrite)

      # Disjoint: ADD.xy vf03, vf01, vf02 | LQ.zw vf03, 0(vi01)
      u_add_xy = (0xC_u32 << 21) | (2_u32 << 16) | (1_u32 << 11) | (3_u32 << 6) | 0x28_u32
      l_lq_zw = (0x00_u32 << 25) | (0x3_u32 << 21) | (3_u32 << 16) | (1_u32 << 11)
      clean_inst = Cradare2::PS2::VUProfiler.decode_instruction(l_lq_zw, u_add_xy, 0_u32)
      prof.analyze_hazards([clean_inst]).should be_empty
    end
  end

  describe "r2pipe Bridge & Declarative DSL (0x11008000 / 0x1100C000)" do
    it "profiles VU1 micro-memory and inspects VU1 data memory & XGKICK GIF packets over r2pipe" do
      u_add = (0xF_u32 << 21) | (2_u32 << 16) | (1_u32 << 11) | (3_u32 << 6) | 0x28_u32
      l_kick = 0x800006FC_u32 | (0_u32 << 11)
      u_end = 0x400002FF_u32
      u_nop = 0x000002FF_u32
      l_nop = 0x8000033C_u32

      micro_bytes = pack_vu1_words([
        {l_kick, u_add},
        {l_nop, u_end},
        {l_nop, u_nop},
      ])

      # Build 2 quadwords in VU1 Data Memory (0x1100C000):
      # QW 0: GIFTag (NLOOP=1, EOP=1, FLG=0 PACKED, NREG=1, REGS=0x0E A+D)
      # QW 1: PRIM register (reg 0x00, data=6 SPRITE)
      data_bytes = Bytes.new(32)
      gif_low = 1_u64 | (1_u64 << 15) | (1_u64 << 60)
      gif_high = 0x0E_u64
      IO::ByteFormat::LittleEndian.encode(gif_low, data_bytes[0, 8])
      IO::ByteFormat::LittleEndian.encode(gif_high, data_bytes[8, 8])
      IO::ByteFormat::LittleEndian.encode(6_u64, data_bytes[16, 8])
      IO::ByteFormat::LittleEndian.encode(0x00_u64, data_bytes[24, 8])

      t0_reads = 0
      mock = Cradare2::Transport::MockTransport.new do |cmd|
        if cmd.starts_with?("pxj") && cmd.includes?("0x11008000")
          bytes_to_pxj(micro_bytes)
        elsif cmd.starts_with?("pxj") && cmd.includes?("0x1100c000")
          bytes_to_pxj(data_bytes)
        elsif cmd.starts_with?("pxj 4 @ 0x10003ce0") # VIF1_TOP
          "[16, 0, 0, 0]"
        elsif cmd.starts_with?("pxj 4 @ 0x10003cc0") # VIF1_TOPS
          "[32, 0, 0, 0]"
        elsif cmd.starts_with?("pxj 4 @ 0x10000000") # EE_T0_COUNT
          t0_reads += 1
          "[#{t0_reads * 70}, 0, 0, 0]"
        else
          "[0, 0, 0, 0]"
        end
      end

      client = Cradare2::Client.new(mock)

      # Tier 2 Declarative DSL via Cradare2.vu_profiler
      report = Cradare2.vu_profiler(client) do |prof|
        prof.start_pc = 0_u32
        prof.max_instructions = 8
      end

      report.instruction_count.should eq(3)
      report.dual_issue_count.should eq(1)
      report.xgkick_count.should eq(1)
      report.clean?.should be_true
      report.summary.should contain("VU1 Profile @ 0x11008000")

      # Inspect VU1 Data Memory (0x1100C000) & embedded GIF packet
      snap = client.ps2.vu_profiler.inspect_data_memory(qw_offset: 0, qw_count: 2)
      snap.base_address.should eq(0x1100C000_u64)
      snap.quadwords.size.should eq(2)
      snap.vif1_top.should eq(16_u32)
      snap.vif1_tops.should eq(32_u32)

      items = snap.dissect_gif_packet_at(0)
      items.size.should eq(1)
      items[0].reg_name.should eq("PRIM")
      items[0].description.should contain("Type=SPRITE")

      # Measure EE Timer 0 cycles around an operation
      elapsed = client.vu_profiler.measure_ee_cycles { }
      elapsed.should eq(70_u32)
    end
  end

  describe "GDB Remote Serial Protocol Bridge (Cradare2::Gdb::Client)" do
    it "profiles VU1 micro-memory over a live GDB RSP socket connection" do
      u_nop = 0x000002FF_u32
      l_nop = 0x8000033C_u32
      u_end = 0x400002FF_u32
      micro_bytes = pack_vu1_words([
        {l_nop, u_end},
        {l_nop, u_nop},
      ])

      server = TCPServer.new("127.0.0.1", 0)
      port = server.local_address.port

      spawn do
        if client_sock = server.accept?
          begin
            # Read initial '+' ack
            client_sock.read_byte
            # Read '$m11008000,10#xx' packet
            buf = IO::Memory.new
            while b = client_sock.read_byte
              ch = b.chr
              if ch == '#'
                client_sock.read_byte
                client_sock.read_byte
                break
              end
              buf << ch
            end
            # Send '+' ack and hex response packet
            client_sock.write_byte('+'.ord.to_u8)
            hex_payload = micro_bytes.hexstring
            pkt = Cradare2::Gdb::Client.format_packet(hex_payload)
            client_sock.print(pkt)
            client_sock.flush
          ensure
            client_sock.close rescue nil
          end
        end
      end

      gdb = Cradare2::Gdb::Client.new("127.0.0.1", port)
      gdb.connect.should be_true
      begin
        report = gdb.profile_vu1 do |prof|
          prof.start_pc = 0_u32
          prof.max_instructions = 2
        end
        report.instruction_count.should eq(2)
        report.terminated_by_e_bit.should be_true
        report.total_cycles.should eq(2)
      ensure
        gdb.close
        server.close rescue nil
      end
    end
  end
end
