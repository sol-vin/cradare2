require "./spec_helper"
require "../src/cradare2/tui/explorer"

describe Cradare2::TUI::ExplorerModel do
  it "initializes model with functions from client" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.functions.size.should eq(2)
    model.filtered_functions.size.should eq(2)
    model.selected_func_idx.should eq(0)
    model.active_tab.should eq(0)
    model.focus_pane.should eq(:list)
    model.side_by_side?.should be_true
    model.show_asm?.should be_true
    model.active_function.not_nil!.name.should eq("sym.main")
  end

  it "switches tabs on '1', '2', and '3' keypresses" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.update(Opal::TEA::KeyMsg.new("2"))
    model.active_tab.should eq(1)

    model.update(Opal::TEA::KeyMsg.new("3"))
    model.active_tab.should eq(2)

    model.update(Opal::TEA::KeyMsg.new("1"))
    model.active_tab.should eq(0)
  end

  it "toggles focus pane between list and code on tab" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.focus_pane.should eq(:list)
    model.update(Opal::TEA::KeyMsg.new("tab"))
    model.focus_pane.should eq(:code)

    model.update(Opal::TEA::KeyMsg.new("tab"))
    model.focus_pane.should eq(:list)
  end

  it "toggles side-by-side mode and asm/decomp view options" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.side_by_side?.should be_true
    model.update(Opal::TEA::KeyMsg.new("s"))
    model.side_by_side?.should be_false

    model.update(Opal::TEA::KeyMsg.new("c"))
    model.show_asm?.should be_false

    model.update(Opal::TEA::KeyMsg.new("a"))
    model.show_asm?.should be_true
  end

  it "navigates function selection with j/k, down/up, and page navigation" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.selected_func_idx.should eq(0)
    model.update(Opal::TEA::KeyMsg.new("j"))
    model.selected_func_idx.should eq(1)

    # Clamped at bounds
    model.update(Opal::TEA::KeyMsg.new("down"))
    model.selected_func_idx.should eq(1)

    model.update(Opal::TEA::KeyMsg.new("k"))
    model.selected_func_idx.should eq(0)

    model.update(Opal::TEA::KeyMsg.new("up"))
    model.selected_func_idx.should eq(0)

    model.update(Opal::TEA::KeyMsg.new("pagedown"))
    model.selected_func_idx.should eq(1)

    model.update(Opal::TEA::KeyMsg.new("pageup"))
    model.selected_func_idx.should eq(0)
  end

  it "scrolls code when focus pane is :code" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.update(Opal::TEA::KeyMsg.new("tab"))
    model.focus_pane.should eq(:code)
    model.code_scroll.should eq(0)

    model.update(Opal::TEA::KeyMsg.new("j"))
    model.code_scroll.should eq(1)

    model.update(Opal::TEA::KeyMsg.new("pagedown"))
    model.code_scroll.should eq(11)

    model.update(Opal::TEA::KeyMsg.new("k"))
    model.code_scroll.should eq(10)

    model.update(Opal::TEA::KeyMsg.new("pageup"))
    model.code_scroll.should eq(0)
  end

  it "filters functions dynamically via search mode" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    # Activate search
    model.update(Opal::TEA::KeyMsg.new("/"))
    model.searching?.should be_true

    # Type query "crystal"
    "crystal".each_char do |ch|
      model.update(Opal::TEA::KeyMsg.new(ch.to_s))
    end
    model.search_query.should eq("crystal")
    model.filtered_functions.size.should eq(1)
    model.filtered_functions.first.name.should eq("sym.crystal_library_entry")

    # Backspace
    model.update(Opal::TEA::KeyMsg.new("backspace"))
    model.search_query.should eq("crysta")

    # Enter ends searching mode
    model.update(Opal::TEA::KeyMsg.new("enter"))
    model.searching?.should be_false

    # Escape clears search
    model.update(Opal::TEA::KeyMsg.new("escape"))
    model.search_query.should eq("")
    model.filtered_functions.size.should eq(2)
  end

  it "handles window resize messages and renders UI views for all tabs" do
    client = SpecFixtures.build_mock_client
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("pdf @ 0x401000", "0x00401000  sub rsp, 0x28\n0x00401004  ret\n")
    mock.on("pdc @ 0x401000", "int main() {\n  return 0;\n}\n")

    model = Cradare2::TUI::ExplorerModel.new(client)
    model.init.should_not be_nil

    # Resize window
    model.update(Opal::TEA::WindowSizeMsg.new(120, 35))
    model.width.should eq(120)
    model.height.should eq(35)

    # Render Code Explorer (Tab 0)
    v0 = model.view(100, 30)
    v0.should contain("Code Explorer")
    v0.should contain("Functions")

    # Render Sections (Tab 1)
    model.update(Opal::TEA::KeyMsg.new("2"))
    v1 = model.view(100, 30)
    v1.should contain("Binary Sections")

    # Render Security (Tab 2)
    model.update(Opal::TEA::KeyMsg.new("3"))
    v2 = model.view(100, 30)
    v2.should contain("Security Posture")
  end

  it "quits on 'q' or 'ctrl+c'" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    _, cmd = model.update(Opal::TEA::KeyMsg.new("q"))
    cmd.quit?.should be_true

    _, cmd2 = model.update(Opal::TEA::KeyMsg.new("ctrl+c"))
    cmd2.quit?.should be_true
  end

  it "renders single pane view toggled via 's' with asm and decomp" do
    client = SpecFixtures.build_mock_client
    mock = client.transport.as(Cradare2::Transport::MockTransport)
    mock.on("pdf @ 0x401000", "sub rsp, 0x28\n")
    mock.on("pdc @ 0x401000", "int main() { return 0; }\n")

    model = Cradare2::TUI::ExplorerModel.new(client)
    # Toggle off side-by-side
    model.update(Opal::TEA::KeyMsg.new("s"))
    model.side_by_side?.should be_false

    # Single pane with asm
    v_asm = model.view(100, 30)
    v_asm.should contain("Code Explorer")

    # Toggle to decomp in single pane
    model.update(Opal::TEA::KeyMsg.new("c"))
    model.show_asm?.should be_false
    v_dec = model.view(100, 30)
    v_dec.should contain("Code Explorer")
  end

  it "handles backspace when search query is empty" do
    client = SpecFixtures.build_mock_client
    model = Cradare2::TUI::ExplorerModel.new(client)

    model.update(Opal::TEA::KeyMsg.new("/"))
    model.search_query.should eq("")
    model.update(Opal::TEA::KeyMsg.new("backspace"))
    model.search_query.should eq("")
  end
end
