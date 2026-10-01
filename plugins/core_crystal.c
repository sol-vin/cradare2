/*
 * radare2 Crystal Plugin (RCorePlugin)
 * 
 * Provides first-class Crystal language support inside radare2:
 * - Demangling of Crystal and MSVC/LLVM PDB-escaped symbols
 * - Source-line-to-assembly matching and `CL` synchronization
 * - In-session delegation to `r2-crystal` CLI tool
 *
 * Author: sol-vin <ian@sol.vin>
 * License: MIT
 */

#include <r_core.h>
#include <r_lib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CRYSTAL_PLUGIN_VERSION "1.0.0"

static void decode_pdb_escapes(const char *in, char *out, size_t out_sz) {
    size_t i = 0, o = 0;
    size_t in_len = strlen(in);

    while (i < in_len && o < out_sz - 1) {
        // Match _XX. or .XX. anywhere
        if ((in[i] == '.' || in[i] == '_') && (i + 3 < in_len) && in[i + 3] == '.') {
            char hex[3] = { in[i + 1], in[i + 2], '\0' };
            char *endptr = NULL;
            long val = strtol(hex, &endptr, 16);
            if (endptr && *endptr == '\0' && val > 0 && val < 128) {
                out[o++] = (char)val;
                i += 4;
                continue;
            }
        }
        out[o++] = in[i++];
    }
    out[o] = '\0';
}

static void print_crystal_help(RCore *core) {
    r_cons_printf(
        core->cons,
        "Usage: crystal <command> [args...] - Crystal Language Plugin for radare2\n\n"
        "Commands:\n"
        "  crystal help                  Show this help menu\n"
        "  crystal detect                Detect if current binary is Crystal\n"
        "  crystal demangle <symbol>     Demangle a Crystal or PDB symbol\n"
        "  crystal demangle-all          Demangle and rename all functions/symbols\n"
        "  crystal lines [func|addr]     Display source-line-to-asm mappings\n"
        "  crystal lines sync            Sync lines to r2 CL table and CC comments\n"
        "  crystal src <addr>            Display source code context for address\n"
        "  crystal asm <file:line>       Display machine instructions for source line\n"
        "  crystal interleaved <func>    Display interleaved source and assembly view\n"
        "  crystal inspect <type> <addr> Inspect Crystal String, Array, or Slice in memory\n"
    );
}

static bool r_cmd_crystal_call(RCorePluginSession *ctx, const char *input) {
    if (!r_str_startswith(input, "crystal")) {
        return false;
    }

    RCore *core = ctx->core;
    const char *args = input + 7;
    while (*args == ' ') {
        args++;
    }

    if (*args == '\0' || !strcmp(args, "help") || !strcmp(args, "-h") || !strcmp(args, "?")) {
        print_crystal_help(core);
        return true;
    }

    // Direct C-level demangling support
    if (r_str_startswith(args, "demangle ")) {
        const char *sym = args + 9;
        while (*sym == ' ') sym++;
        if (*sym) {
            char decoded[1024];
            decode_pdb_escapes(sym, decoded, sizeof(decoded));
            const char *clean = decoded;
            if (r_str_startswith(clean, "sym.imp.")) clean += 8;
            else if (r_str_startswith(clean, "sym.pdb.")) clean += 8;
            else if (r_str_startswith(clean, "sym.")) clean += 4;
            else if (r_str_startswith(clean, "pdb.")) clean += 4;
            if (*clean == '*' || *clean == '~') clean++;
            r_cons_printf(core->cons, "%s -> %s\n", sym, clean);
            return true;
        }
    }

    // Delegate to r2-crystal binary if available via #!pipe
    char pipe_cmd[1024];
    snprintf(pipe_cmd, sizeof(pipe_cmd), "#!pipe r2-crystal %s", args);
    r_core_cmd0(core, pipe_cmd);
    return true;
}

RCorePlugin r_core_plugin_crystal = {
    .meta = {
        .name = "crystal",
        .desc = "Crystal language plugin for radare2 with source line matching and demangling",
        .author = "sol-vin",
        .version = CRYSTAL_PLUGIN_VERSION,
        .license = "MIT",
    },
    .call = r_cmd_crystal_call,
};

#ifndef R2_PLUGIN_INCORE
R_API RLibStruct radare_plugin = {
    .type = R_LIB_TYPE_CORE,
    .data = &r_core_plugin_crystal,
    .version = R2_VERSION
};
#endif
