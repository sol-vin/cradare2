# Radare2 Plugin Development in Crystal Guide

This guide explains how to write native and in-session radare2 plugins using the `cradare2` plugin framework.

---

## 1. Overview of radare2 Plugin Types

Radare2 supports several extension mechanisms:

| Mechanism | Description | Speed | Complexity | Use Case |
|---|---|---|---|---|
| **`#!pipe` Script** | Script executed via `#<program` or `#!pipe` in r2 shell | High | Very Low | Analysis scripts, engine inspectors, formatters |
| **Interactive Pipe Server** | Long-running daemon responding to piped commands | Maximum | Low | Interactive toolkits, continuous debugging sidecars |
| **Native C Plugin** | Dynamic library loaded into r2 plugin directory | Instant | Medium | Core command additions, native architecture plugins |

`cradare2` provides complete infrastructure for all three models.

---

## 2. The Modular Command Architecture

In `cradare2`, commands are implemented as standalone classes inheriting from `Cradare2::Plugin::Command`:

```crystal
require "cradare2"

class MyCustomCommand < Cradare2::Plugin::Command
  # Primary command name
  def name : String
    "status"
  end

  # Command aliases
  def aliases : Array(String)
    ["st", "stat"]
  end

  # One-line description for help text
  def description : String
    "Display engine subsystem status"
  end

  # Execution logic
  # args: arguments passed after the command name
  # as_json: true if the user invoked with -j or --json
  def execute(args : Array(String), as_json : Bool = false) : String
    status_data = {
      "fps" => 60,
      "entities" => 1024,
      "physics_ticks" => 60
    }

    if as_json
      status_data.to_json
    else
      "Engine Status: #{status_data["fps"]} FPS, #{status_data["entities"]} Entities"
    end
  end
end
```

---

## 3. Configuring the Command Dispatcher

The `CommandDispatcher` routes incoming command lines to registered subcommands.

### 3.1 Custom Command Prefixes
By default, `CommandDispatcher` responds to the `crystal` prefix (`crystal help`, `crystal info`). When building an engine plugin (e.g. for Godot or Lapis), set a custom `@prefix`:

```crystal
client = Cradare2.open("my_game.exe")

# Initialize dispatcher with 'godot' prefix
dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")

# Register custom commands
dispatcher.register(MyCustomCommand.new(client))

# Dispatch commands
puts dispatcher.dispatch("godot status")
# => "Engine Status: 60 FPS, 1024 Entities"

puts dispatcher.dispatch("godot status -j")
# => "{\"fps\":60,\"entities\":1024,\"physics_ticks\":60}"
```

### 3.2 Built-In Help & Command Routing
The dispatcher automatically:
- Formats help text (`godot help` or `godot ?`).
- Resolves aliases (`godot st` -> `MyCustomCommand`).
- Strips universal JSON flags (`-j` / `--json`) and passes `as_json: true` to the command.
- Returns error messages if arguments are invalid or commands are unknown.

---

## 4. Running an Interactive Pipe Server (`Plugin::Server`)

When running inside radare2 (`r2 -i my_plugin.cr` or `#<my_plugin`), you can launch an interactive pipe server loop that handles commands in real time:

```crystal
# tools/r2_godot.cr
require "cradare2"

# 1. Connect to parent radare2 session
client = Cradare2.in_session

# 2. Configure dispatcher with 'godot' prefix
dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "godot")
dispatcher.register(MyCustomCommand.new(client))

# 3. Enter interactive dispatch loop
Cradare2::Plugin::Server.run(dispatcher)
```

Inside radare2:
```text
[0x140001000]> #!pipe crystal run tools/r2_godot.cr
[0x140001000]> godot status
Engine Status: 60 FPS, 1024 Entities
[0x140001000]> godot status -j
{"fps":60,"entities":1024,"physics_ticks":60}
```

---

## 5. Standalone CLI Binary with OptionParser

To make your plugin executable from both the shell and within radare2, use `OptionParser`:

```crystal
# src/bin/r2_mytool.cr
require "cradare2"
require "option_parser"

server_mode = false
json_output = false

parser = OptionParser.parse do |opts|
  opts.banner = "Usage: r2-mytool [options] <binary> [command]"
  opts.on("-s", "--server", "Run in interactive pipe server mode") { server_mode = true }
  opts.on("-j", "--json", "Output results in JSON format") { json_output = true }
  opts.on("-h", "--help", "Show help") do
    puts opts
    exit 0
  end
end

if server_mode
  client = Cradare2.in_session
  dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "mytool")
  Cradare2::Plugin::Server.run(dispatcher)
else
  target = ARGV.first? || abort("Missing binary path")
  cmd = ARGV[1..]? || ["help"]

  Cradare2.open(target) do |client|
    dispatcher = Cradare2::Plugin::CommandDispatcher.new(client, prefix: "mytool")
    full_cmd = "mytool #{cmd.join(" ")}#{json_output ? " -j" : ""}"
    puts dispatcher.dispatch(full_cmd)
  end
end
```

---

## 6. Native C Core Plugin Integration

For zero-startup overhead, `cradare2` includes a C core plugin in `plugins/core_crystal.c`.

### 6.1 Compiling the Native Plugin
```powershell
# Windows
cd plugins
.\build.ps1
```
```bash
# Linux / macOS
cd plugins
make
```

### 6.2 Plugin Structure
The C plugin defines a radare2 `RCorePlugin` that hooks command dispatch:
```c
static int r_cmd_crystal_call(void *user, const char *cmd) {
    if (r_str_startswith(cmd, "crystal")) {
        // Pipes execution to r2-crystal binary or server
        return true;
    }
    return false;
}

RCorePlugin r_core_plugin_crystal = {
    .name = "crystal",
    .desc = "Crystal binary analysis and source line matching plugin",
    .license = "MIT",
    .call = r_cmd_crystal_call,
};
```
Installed into `~/.local/share/radare2/plugins/`, radare2 will automatically recognize the custom command prefix natively.
