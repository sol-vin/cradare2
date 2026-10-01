# Build script for core_crystal native radare2 plugin

$ErrorActionPreference = "Stop"

$r2_prefix = "C:\Users\Ian\scoop\apps\radare2\current"
$inc_dir = "$r2_prefix\include\libr"
$lib_dir = "$r2_prefix\lib"
$plugin_dir = "C:\Users\Ian\.local\share\radare2\plugins"

if (!(Test-Path $plugin_dir)) {
    New-Item -ItemType Directory -Force -Path $plugin_dir | Out-Null
}

$target_dll = "$plugin_dir\core_crystal.dll"
$src = "$PSScriptRoot\core_crystal.c"

Write-Host "Compiling native radare2 plugin: $src -> $target_dll"

# Compile with clang
clang -shared -O2 -I"$inc_dir" -L"$lib_dir" -lr_core -lr_util -lr_cons -o "$target_dll" "$src"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Successfully built and installed: $target_dll"
} else {
    Write-Host "Compilation failed with code $LASTEXITCODE" -ForegroundColor Red
}
