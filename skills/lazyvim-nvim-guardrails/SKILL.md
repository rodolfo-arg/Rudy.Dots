---
name: lazyvim-nvim-guardrails
description: Guardrails for working on LazyVim/Neovim config, kotlin-android-lsp plugin, and Nix home-manager integration in /Users/rodolfo/Rudy.Dots. Use when editing nvim config, LazyVim plugins, Mason/LSP/treesitter setup, Kotlin/Java LSP workspace generation, or Nix/Home Manager wiring; enforces switch-first workflow, single-source-of-truth config, web research for Lua/Nix docs, and awareness of known issues.
---

# LazyVim/Nvim Guardrails

## Overview
Keep /Users/rodolfo/Rudy.Dots as the single source of truth for Neovim/LazyVim and Nix config. All changes must be applied via the switch workflow; do not manually re-enable plugins or LSPs outside the config.

## Core requirements (non-negotiable)
- Single source of truth: edit only the repo config (no direct edits in ~/.config/nvim or other generated paths).
- Switch-first: after every change, run `scripts/clean-nvim-and-switch` before testing or opening Neovim.
- No manual re-enable: do not suggest ad-hoc `:Lazy sync`, `:TSInstallSync`, or LSP restarts as the primary fix. Encode fixes in the repo and re-run the switch.
- Automate anything repeatable: if a manual step is needed, add it to the repo (scripts/config) and switch again.
- Commit and push after each change: ensures work is preserved and reviewable incrementally.

Reveal manual commands only when debugging a failed switch, and document why they were required.

## kotlin-android-lsp Plugin

Local plugin at `nvim/lua/kotlin-android-lsp/` providing Kotlin/Android/Java LSP support.

### Commands & Keymaps
- `<leader>dk` / `:KotlinWorkspaceGenerate` - Generate workspace.json for current project
- `<leader>di` / `:KotlinWorkspaceInfo` - Show workspace info (project type, versions, LSP status)
- `:checkhealth kotlin-android-lsp` - Health check for dependencies

### Plugin Modules
- `init.lua` - Main entry, setup(), commands, keymaps
- `config.lua` - Configuration with defaults
- `uri.lua` - Bidirectional jar:/zipfile:// URI mapping
- `attach.lua` - LSP attachment for jar source buffers
- `workspace.lua` - Workspace generation with Gradle project detection
- `health.lua` - Health check module

### When modifying the plugin
1. Edit files in `nvim/lua/kotlin-android-lsp/`
2. Run `scripts/clean-nvim-and-switch`
3. Test with `<leader>dk` and `:checkhealth kotlin-android-lsp`
4. Commit and push changes

## Workflow (required)
1) Make edits in /Users/rodolfo/Rudy.Dots.
2) Run `scripts/clean-nvim-and-switch` (optionally with env vars for workspace generation).
3) Verify behavior in Neovim or via logs.
4) If a regression remains, update config/scripts and repeat the switch.
5) Commit and push after each logical change.

Workspace generation (optional, but must be automated when needed):
- `KOTLIN_LSP_PROJECT_ROOT=/path/to/project`
- `KOTLIN_LSP_MODULE=app` (default)
- Or use `<leader>dk` interactively in Neovim

## Research requirements (Lua + Nix)
- Use web search (web.run) for Lua/Neovim/LazyVim/nvim-treesitter/lspconfig references before making or explaining changes.
- Use web search (web.run) for Nix, nixpkgs, and home-manager option documentation before editing Nix files.
- Prefer official docs or primary sources; summarize the key points in responses with citations.

## LSP Configuration

### kotlin_lsp (JetBrains)
- Binary: `~/.nix-profile/bin/kotlin-lsp`
- Requires: Java 21+
- Filetypes: `kotlin`
- URI handling: Returns `jar:` URIs, converted to `zipfile://`

### jdtls (Eclipse)
- Binary: `~/.nix-profile/bin/jdtls`
- Requires: Java 21+
- Filetypes: `java`
- Single-file support: Enabled for zipfile:// buffers
- URI handling: Uses `jdt://` URIs

## Known issues to remember
- `E492: Not an editor command: TSInstallSync kotlin` - keep `nvim-treesitter` non-lazy and install Kotlin via Lua API during switch.
- If `kotlin_lsp` not in `:LspInfo`, check PATH or `~/.nix-profile/bin/kotlin-lsp` fallback.
- Kotlin LSP zip has read-only JRE in Nix store; use wrapper script with system Java.
- Workspace JSON fails with old schema (`value` wrapper, `COMPILE`/`ROOT_ITSELF`); regenerate after script changes.
- Extra LazyVim language packs (astro/angular/nix) cause Mason errors; keep removed.
- `kotlin_language_server` must stay disabled; use `kotlin_lsp` only.
- Kotlin LSP is pre-alpha, JVM-only Gradle support; ensure Java 21+, Gradle, Android SDK env vars.
- **Second-layer Java navigation**: kotlin_lsp doesn't fully support Java→Java navigation within libraries.
- **jdtls in jar sources**: Attaches to zipfile:// buffers but may not provide full navigation (expects jdt:// URIs).
- **Multiple editing sessions**: kotlin-lsp doesn't support multiple sessions; kill old processes before restarting.

## Debugging
- LSP log: `tail -f ~/.local/state/nvim/lsp.log`
- Kotlin LSP focused: `rg "kotlin-lsp|workspace.json|Error" ~/.local/state/nvim/lsp.log`
- Health check: `:checkhealth kotlin-android-lsp`
- Active clients: `:lua print(vim.inspect(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients())))`
