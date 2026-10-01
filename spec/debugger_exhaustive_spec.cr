require "./spec_helper"

describe "Cradare2 Debugger & Breakpoints Exhaustive Suite" do
  describe "1. Advanced Breakpoints & Watchpoints" do
    it "sets and removes software breakpoints fluently" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.breakpoint(0x401000)
      client.debug.breakpoint("main")
      client.remove_breakpoint(0x401000)
      client.remove_breakpoint("main")
      client.clear_breakpoints

      mock.history.should contain("db 0x401000")
      mock.history.should contain("db main")
      mock.history.should contain("db- 0x401000")
      mock.history.should contain("db- main")
      mock.history.should contain("db-*")
    end

    it "sets and removes hardware execution breakpoints (dbH)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.hardware_breakpoint(0x402000)
      client.debug.hw_breakpoint("entry")
      client.hardware_breakpoint(0x403000) # top-level forwarder

      mock.history.should contain("dbH 0x402000")
      mock.history.should contain("dbH entry")
      mock.history.should contain("dbH 0x403000")
    end

    it "sets and removes memory watchpoints with read/write/rw modes (dbw)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.watchpoint(0x500000, :write)
      client.debug.watchpoint(0x500010, :read)
      client.debug.watchpoint(0x500020, :rw)
      client.watchpoint(0x500030, :w) # top-level forwarder
      client.debug.remove_watchpoint(0x500000)
      client.remove_watchpoint(0x500010)

      mock.history.should contain("dbw 0x500000 w")
      mock.history.should contain("dbw 0x500010 r")
      mock.history.should contain("dbw 0x500020 rw")
      mock.history.should contain("dbw 0x500030 w")
      mock.history.should contain("db- 0x500000")
      mock.history.should contain("db- 0x500010")
    end

    it "enables, disables, and toggles breakpoints (dbe, dbd, dbs)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.enable_breakpoint(0x401000)
      client.debug.disable_breakpoint(0x401000)
      client.debug.enable_all_breakpoints
      client.debug.disable_all_breakpoints
      client.debug.toggle_breakpoint(0x401000)

      mock.history.should contain("dbe 0x401000")
      mock.history.should contain("dbd 0x401000")
      mock.history.should contain("dbe*")
      mock.history.should contain("dbd*")
      mock.history.should contain("dbs 0x401000")
    end

    it "names breakpoints and configures conditions / commands (dbn, dbx, dbc)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.name_breakpoint(0x401000, "player_init")
      client.debug.set_breakpoint_condition(0x401000, "rax==1")
      client.debug.conditional_breakpoint(0x402000, "rdx>10")
      client.debug.set_breakpoint_command(0x401000, "dr; dc")

      mock.history.should contain("dbn player_init @ 0x401000")
      mock.history.should contain("dbx rax==1 @ 0x401000")
      mock.history.should contain("db 0x402000")
      mock.history.should contain("dbx rdx>10 @ 0x402000")
      mock.history.should contain("dbc 0x401000 dr; dc")
    end

    it "creates tracepoints / logpoints (dbC)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.tracepoint(0x401500, "?e Hit tracepoint")
      client.debug.logpoint(0x401600, "?e Hit logpoint")

      mock.history.should contain("db 0x401500")
      mock.history.should contain("dbC 0x401500 ?e Hit tracepoint")
      mock.history.should contain("db 0x401600")
      mock.history.should contain("dbC 0x401600 ?e Hit logpoint")
    end

    it "supports source-level line breakpoints with fallback to dbl" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      # Unmapped line falls back to dbl file:line
      client.debug.breakpoint_at_source("src/game.cr", 42)
      mock.history.should contain("dbl src/game.cr:42")
    end

    it "parses and categorizes active breakpoints from JSON (dbj)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      json_payload = <<-JSON
      [
        {"addr": 4198400, "size": 1, "hw": false, "trace": false, "enabled": true, "name": "main_bp", "hits": 3, "data": "dr"},
        {"addr": 4202496, "size": 1, "hw": true, "trace": false, "enabled": true, "name": "hw_bp", "hits": 0},
        {"addr": 4210000, "size": 4, "hw": true, "trace": false, "enabled": false, "name": "watch_data", "perm": "-w-", "cond": "rax==5"}
      ]
      JSON
      mock.on("dbj", json_payload)

      bps = client.debug.breakpoints
      bps.size.should eq(3)

      # 1. Software bp
      bps[0].address.should eq(4198400_u64)
      bps[0].software?.should be_true
      bps[0].hardware?.should be_false
      bps[0].watchpoint?.should be_false
      bps[0].enabled?.should be_true
      bps[0].hit_count.should eq(3)
      bps[0].has_command?.should be_true
      bps[0].command.should eq("dr")

      # 2. Hardware bp
      bps[1].hardware?.should be_true
      bps[1].software?.should be_false
      bps[1].hit_count.should eq(0)

      # 3. Watchpoint
      bps[2].watchpoint?.should be_true
      bps[2].hardware?.should be_true
      bps[2].enabled?.should be_false
      bps[2].conditional?.should be_true
      bps[2].cond.should eq("rax==5")

      # Filtered helpers
      client.debug.software_breakpoints.map(&.address).should eq([4198400_u64])
      client.debug.hardware_breakpoints.map(&.address).should eq([4202496_u64, 4210000_u64])
      client.debug.watchpoints.map(&.address).should eq([4210000_u64])

      # Query helpers
      client.debug.breakpoint_at?(4198400).should be_true
      client.debug.breakpoint_at?(0xdeadbeef).should be_false
      found = client.debug.find_breakpoint(4202496)
      found.should_not be_nil
      found.not_nil!.name.should eq("hw_bp")
    end
  end

  describe "2. Advanced Execution & Stepping Control" do
    it "supports multi-instruction steps, step_over, and step_out" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.step
      client.debug.step(5)
      client.debug.step_over
      client.debug.step_over(3)
      client.debug.step_out
      client.debug.finish
      client.step_out # top-level forwarder

      mock.history.should contain("ds")
      mock.history.should contain("ds 5")
      mock.history.should contain("dso")
      mock.history.should contain("dso 3")
      mock.history.should contain("dsf")
    end

    it "supports source stepping, reverse stepping, and reverse continue" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.step_source
      client.debug.step_source(4)
      client.debug.step_back
      client.debug.continue_back

      mock.history.should contain("dsl")
      mock.history.should contain("dsl 4")
      mock.history.should contain("dsb")
      mock.history.should contain("dcb")
    end

    it "supports conditional continuations (until addr, ret, call, syscall)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.continue_until(0x401080)
      client.debug.continue_until_ret
      client.debug.continue_until_call
      client.debug.continue_until_syscall

      mock.history.should contain("dcu 0x401080")
      mock.history.should contain("dcr")
      mock.history.should contain("dcc")
      mock.history.should contain("dcs")
    end
  end

  describe "3. CPU Flags, ARM Registers, and Diffing" do
    it "decodes standard x86/x64 EFLAGS bits accurately" do
      # 0x01: CF, 0x04: PF, 0x40: ZF, 0x80: SF, 0x200: IF, 0x800: OF
      # Test with ZF and CF set: 0x40 | 0x01 = 0x41
      regs1 = Cradare2::Model::Registers.new({"eflags" => 0x41_u64})
      regs1.zero_flag?.should be_true
      regs1.zf?.should be_true
      regs1.carry_flag?.should be_true
      regs1.cf?.should be_true
      regs1.sign_flag?.should be_false
      regs1.overflow_flag?.should be_false
      regs1.parity_flag?.should be_false
      regs1.interrupt_flag?.should be_false

      # Test with SF, OF, IF, PF set: 0x80 | 0x800 | 0x200 | 0x04 = 0xA84
      regs2 = Cradare2::Model::Registers.new({"eflags" => 0x0a84_u64})
      regs2.zero_flag?.should be_false
      regs2.carry_flag?.should be_false
      regs2.sign_flag?.should be_true
      regs2.overflow_flag?.should be_true
      regs2.interrupt_flag?.should be_true
      regs2.parity_flag?.should be_true
    end

    it "accesses ARM registers (lr, r0-r7)" do
      arm_regs = Cradare2::Model::Registers.new({
        "r0" => 10_u64,
        "r1" => 20_u64,
        "r2" => 30_u64,
        "r3" => 40_u64,
        "r4" => 50_u64,
        "r5" => 60_u64,
        "r6" => 70_u64,
        "r7" => 80_u64,
        "lr" => 0x401000_u64,
      })
      arm_regs.r0.should eq(10_u64)
      arm_regs.r1.should eq(20_u64)
      arm_regs.r2.should eq(30_u64)
      arm_regs.r3.should eq(40_u64)
      arm_regs.r4.should eq(50_u64)
      arm_regs.r5.should eq(60_u64)
      arm_regs.r6.should eq(70_u64)
      arm_regs.r7.should eq(80_u64)
      arm_regs.lr.should eq(0x401000_u64)
    end

    it "computes diffs between register states" do
      old_regs = Cradare2::Model::Registers.new({
        "rax" => 0x1000_u64,
        "rbx" => 0x2000_u64,
        "rcx" => 0x3000_u64,
      })
      new_regs = Cradare2::Model::Registers.new({
        "rax" => 0x1050_u64,
        "rbx" => 0x2000_u64,
        "rcx" => 0x4000_u64,
        "rdx" => 0x5000_u64,
      })

      diff = new_regs.diff(old_regs)
      diff.has_key?("rbx").should be_false
      diff["rax"].should eq({0x1000_u64, 0x1050_u64})
      diff["rcx"].should eq({0x3000_u64, 0x4000_u64})
      diff["rdx"].should eq({0_u64, 0x5000_u64})
    end

    it "takes and restores register snapshots (drs+, drs-)" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.snapshot_registers
      client.debug.restore_registers

      mock.history.should contain("drs+")
      mock.history.should contain("drs-")
    end
  end

  describe "4. Pointer Telescoping (drrj)" do
    it "parses telescoping reference chains into TelescopeEntry models" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      json = <<-JSON
      [
        {"role": "PC", "reg": "rip", "value": "0x401032", "refstr": "sym.Player#_process"},
        {"role": "SP", "reg": "rsp", "value": "0x7fffffffe000", "refstr": "stack"},
        {"role": "A0", "reg": "rdi", "value": "0x555555560000", "refstr": "'PlayerInstance'"}
      ]
      JSON
      mock.on("drrj", json)

      tele = client.debug.telescope
      tele.size.should eq(3)

      tele[0].reg.should eq("rip")
      tele[0].role.should eq("PC")
      tele[0].value_u64.should eq(0x401032_u64)
      tele[0].refstr.should eq("sym.Player#_process")
      tele[0].to_s.should eq("[PC] rip = 0x401032 -> sym.Player#_process")

      tele[2].reg.should eq("rdi")
      tele[2].refstr.should eq("'PlayerInstance'")
    end
  end

  describe "5. Threads & Attachable Processes" do
    it "inspects current thread, selects thread, and tests status predicates" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("dpt.", "202\n")
      mock.on("dptj", <<-JSON
      [
        {"id": 101, "status": "running", "selected": false, "name": "WorkerThread"},
        {"id": 202, "status": "stopped", "selected": true, "name": "MainThread"}
      ]
      JSON
      )

      client.debug.current_thread_id.should eq(202)
      curr = client.debug.current_thread
      curr.should_not be_nil
      curr.not_nil!.id.should eq(202)
      curr.not_nil!.selected?.should be_true
      curr.not_nil!.stopped?.should be_true
      curr.not_nil!.running?.should be_false

      client.debug.select_thread(101)
      mock.history.should contain("dpt=101")
    end

    it "lists attachable processes (dplj) and extracts metadata" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("dplj", <<-JSON
      [
        {"pid": 1337, "ppid": 1, "uid": 1000, "status": "s", "path": "C:\\\\Games\\\\MyGame.exe", "current": true},
        {"pid": 2048, "ppid": 1337, "uid": 1000, "status": "r", "path": "/usr/bin/godot", "current": false}
      ]
      JSON
      )
      mock.on("dpe", "C:\\\\Games\\\\MyGame.exe\n")

      procs = client.debug.attachable_processes
      procs.size.should eq(2)
      procs[0].pid.should eq(1337)
      procs[0].current?.should be_true
      procs[0].name.should eq("MyGame.exe")

      procs[1].pid.should eq(2048)
      procs[1].current?.should be_false
      procs[1].name.should eq("godot")

      client.debug.executable_path.should eq("C:\\\\Games\\\\MyGame.exe")
    end
  end

  describe "6. Stack Words & Memory Protection / Allocation" do
    it "reads stack words from current SP" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      mock.on("drj", "{\"rsp\": 4198400}")
      mock.on("pxj 16 @ 0x401000", "[0, 16, 64, 0, 0, 0, 0, 0, 16, 16, 64, 0, 0, 0, 0, 0]")

      words = client.debug.stack_words(2)
      words.should eq([0x401000_u64, 0x401010_u64])
    end

    it "protects, allocates, deallocates, and dumps memory" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      client.debug.protect_memory(0x401000, 4096, "r-x")
      client.debug.allocate_memory(8192)
      client.debug.allocate_memory(4096, 0x500000)
      client.debug.deallocate_memory(0x500000)
      client.debug.dump_memory_region("mem.dmp")

      mock.history.should contain("dmp 0x401000 4096 r-x")
      mock.history.should contain("dm -1 8192")
      mock.history.should contain("dm 0x500000 4096")
      mock.history.should contain("dm- 0x500000")
      mock.history.should contain("dmd mem.dmp")
    end
  end

  describe "7. Live Radare2 Integration (malloc://64 target)" do
    it "sets and manipulates breakpoints against live radare2 process when present" do
      r2_bin = Process.find_executable("r2") || Process.find_executable("radare2")
      if r2_bin
        transport = Cradare2::Transport::ProcessTransport.new("malloc://64")
        client = Cradare2::Client.new(transport)
        begin
          # Set software breakpoints
          client.debug.breakpoint(0x10)
          client.debug.breakpoint_at?(0x10).should be_true

          client.debug.breakpoint(0x20)
          client.debug.breakpoint_at?(0x20).should be_true
          bps = client.debug.breakpoints
          bps.size.should be >= 2

          # Toggle
          client.debug.toggle_breakpoint(0x10)
          client.debug.breakpoint_at?(0x10).should be_false

          # Clear all
          client.debug.clear_breakpoints
          client.debug.breakpoints.should be_empty
        ensure
          client.close
        end
      end
    end
  end

  describe "8. Crash Diagnostics & Error Resiliency" do
    it "diagnoses null dereference crash cause and provides engine-specific tips" do
      client = Cradare2.mock
      regs = Cradare2::Model::Registers.new({
        "rip" => 0x401032_u64,
        "rax" => 0x0_u64,
        "rsp" => 0x7fffffffe000_u64,
        "rbp" => 0x7fffffffe040_u64,
      })
      diag = client.debug.diagnose_crash(regs: regs)
      diag.probable_cause.should eq(:null_dereference)
      diag.faulting_address.should eq(0x401032_u64)
      diag.recommendations.any? { |r| r.includes?("Null pointer dereference") }.should be_true
      diag.recommendations.any? { |r| r.includes?("Godot/Lapis") }.should be_true
    end

    it "diagnoses null branch crash cause" do
      client = Cradare2.mock
      regs = Cradare2::Model::Registers.new({
        "rip" => 0x0_u64,
        "rsp" => 0x7fffffffe000_u64,
        "rbp" => 0x7fffffffe040_u64,
      })
      diag = client.debug.diagnose_crash(regs: regs)
      diag.probable_cause.should eq(:null_branch)
      diag.recommendations.any? { |r| r.includes?("low memory address") }.should be_true
    end

    it "diagnoses wild jump into unmapped address" do
      client = Cradare2.mock
      regs = Cradare2::Model::Registers.new({
        "rip" => 0xdeadbeef_u64,
        "rsp" => 0x7fffffffe000_u64,
        "rbp" => 0x7fffffffe040_u64,
      })
      diag = client.debug.diagnose_crash(regs: regs)
      diag.probable_cause.should eq(:wild_jump)
      diag.recommendations.any? { |r| r.includes?("unmapped memory") }.should be_true
    end

    it "diagnoses stack corruption" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("dmj", "[{\"name\": \"main.exe\", \"from\": 4194304, \"to\": 4200000, \"perm\": \"r-x\"}]")

      regs = Cradare2::Model::Registers.new({
        "rip" => 4195000_u64,
        "rax" => 4195000_u64,
        "rsp" => 0_u64,
        "rbp" => 0_u64,
      })

      diag = client.debug.diagnose_crash(regs: regs)
      diag.probable_cause.should eq(:stack_corruption)
      diag.recommendations.any? { |r| r.includes?("Stack pointer corrupted") }.should be_true
    end

    it "handles empty responses gracefully in query helpers" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("dptj", "invalid json")
      mock.on("dbj", "invalid json")
      mock.on("drj", "invalid json")
      mock.on("dbtj", "invalid json")
      mock.on("dmj", "invalid json")
      mock.on("drrj", "invalid json")
      mock.on("dplj", "invalid json")

      client.debug.threads.should be_empty
      client.debug.breakpoints.should be_empty
      client.debug.registers.all_registers.should be_empty
      client.debug.backtrace.should be_empty
      client.debug.maps.should be_empty
      client.debug.telescope.should be_empty
      client.debug.attachable_processes.should be_empty
      client.debug.stack_words.should be_empty
    end

    it "resolves source breakpoint when Crystal Line mapping exists" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)

      # Register a synthetic source mapping
      client.crystal.lines.map.add(0x401234_u64, "src/player.cr", 25)

      client.debug.breakpoint_at_source("src/player.cr", 25)
      mock.history.should contain("db 0x401234")
    end
  end

  describe "9. Model Instantiation & Edge Cases" do
    it "instantiates Breakpoint with custom constructor" do
      bp = Cradare2::Model::Breakpoint.new(
        raw_addr: 0x401000_u64,
        size: 1,
        hw: false,
        enabled: true,
        name: "test_bp",
        hits: 10,
        cmd: "dc"
      )
      bp.address.should eq(0x401000_u64)
      bp.hit_count.should eq(10)
      bp.command.should eq("dc")
      bp.has_command?.should be_true
      bp.software?.should be_true
      bp.valid?.should be_true
    end

    it "instantiates Thread with custom constructor and tests predicates" do
      th_run = Cradare2::Model::Thread.new(id: 1, status: "Runnable", selected: true, name: "Worker-1")
      th_run.running?.should be_true
      th_run.stopped?.should be_false
      th_run.selected?.should be_true

      th_stop = Cradare2::Model::Thread.new(id: 2, status: "Suspended", selected: false, name: "Worker-2")
      th_stop.running?.should be_false
      th_stop.stopped?.should be_true
      th_stop.selected?.should be_false
    end

    it "instantiates TelescopeEntry and converts hex/dec values" do
      t1 = Cradare2::Model::TelescopeEntry.new("rax", "0x1234", "pointer to heap", "A0")
      t1.value_u64.should eq(0x1234_u64)
      t1.to_s.should contain("rax = 0x1234 -> pointer to heap")

      t2 = Cradare2::Model::TelescopeEntry.new("rbx", "4096")
      t2.value_u64.should eq(4096_u64)
      t2.to_s.should eq("rbx = 4096")
    end

    it "instantiates ProcessInfo and extracts path / name" do
      p1 = Cradare2::Model::ProcessInfo.new(pid: 1234, path: "C:\\Windows\\System32\\cmd.exe", current: true)
      p1.pid.should eq(1234)
      p1.current?.should be_true
      p1.name.should eq("cmd.exe")
      p1.to_s.should contain("PID 1234: cmd.exe")

      p2 = Cradare2::Model::ProcessInfo.new(pid: 5678, path: "/usr/bin/bash")
      p2.name.should eq("bash")

      p3 = Cradare2::Model::ProcessInfo.new(pid: 9999)
      p3.name.should eq("unknown")
    end

    it "tests watchpoint permission detection edge cases" do
      bp_read = Cradare2::Model::Breakpoint.new(perm: "r--")
      bp_read.watchpoint?.should be_true

      bp_write = Cradare2::Model::Breakpoint.new(perm: "-w-")
      bp_write.watchpoint?.should be_true

      bp_rw = Cradare2::Model::Breakpoint.new(perm: "rw-")
      bp_rw.watchpoint?.should be_true

      bp_exec = Cradare2::Model::Breakpoint.new(perm: "r-x")
      bp_exec.watchpoint?.should be_false

      bp_rwx = Cradare2::Model::Breakpoint.new(perm: "rwx")
      bp_rwx.watchpoint?.should be_false

      bp_none = Cradare2::Model::Breakpoint.new(perm: nil)
      bp_none.watchpoint?.should be_false
    end

    it "tests breakpoint conditional predicates" do
      bp_cond = Cradare2::Model::Breakpoint.new(cond: "rax == 1")
      bp_cond.conditional?.should be_true

      bp_empty = Cradare2::Model::Breakpoint.new(cond: "")
      bp_empty.conditional?.should be_false

      bp_nil = Cradare2::Model::Breakpoint.new(cond: nil)
      bp_nil.conditional?.should be_false
    end
  end

  describe "10. Client Top-Level Forwarders" do
    it "invokes debugging methods directly from Client" do
      client = Cradare2.mock
      mock = client.transport.as(Cradare2::Transport::MockTransport)
      mock.on("drj", "{\"rip\": 4198400, \"rsp\": 140000000}")
      mock.on("dbtj", "[{\"addr\": 4198400, \"pc\": 4198400, \"function\": \"main\"}]")
      mock.on("dbj", "[{\"addr\": 4198400, \"enabled\": true}]")

      client.hardware_breakpoint(0x401000)
      client.watchpoint(0x402000, :rw)
      client.remove_watchpoint(0x402000)
      client.clear_breakpoints
      client.step
      client.step(3)
      client.step_over
      client.step_over(2)
      client.step_out
      client.continue

      mock.history.should contain("dbH 0x401000")
      mock.history.should contain("dbw 0x402000 rw")
      mock.history.should contain("db- 0x402000")
      mock.history.should contain("db-*")
      mock.history.should contain("ds")
      mock.history.should contain("ds 3")
      mock.history.should contain("dso")
      mock.history.should contain("dso 2")
      mock.history.should contain("dsf")
      mock.history.should contain("dc")

      client.registers.rip.should eq(4198400_u64)
      client.backtrace.size.should eq(1)
      client.breakpoints.size.should eq(1)
      client.diagnose_crash.should_not be_nil
    end
  end
end
