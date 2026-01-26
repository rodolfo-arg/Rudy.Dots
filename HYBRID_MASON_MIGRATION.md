# Hybrid Mason Migration (Nix-first)

Date: 2026-01-21
Repo: /Users/rodolfo/Rudy.Dots

## Goal
- Keep Mason installed but prevent auto-installs during `Lazy! sync` and headless switches.
- Prefer Nix/Home Manager for LSP/DAP/formatter/linter binaries on PATH.
- Use Mason only when nixpkgs lacks a tool or for short-lived experiments.

## What changed in this repo
- `nvim/lua/plugins/mason.lua`: disable Mason auto-installs and auto-enabling.
- `nvim/lua/plugins/kotlin.lua`: Kotlin LSP resolves from PATH first; Mason is a fallback.
- `nvim/lua/plugins/clang.lua`: clangd resolves from PATH (Nix-managed).
- `scripts/clean-nvim-and-switch`: still bootstraps Lazy + Tree-sitter during switch.

## Migration steps (hybrid workflow)
1) Choose a source for each tool:
   - Preferred: add it to Nix `home.packages` in `flake.nix` so it is on PATH after the switch.
   - Exception: use Mason only for tools missing from nixpkgs or for temporary testing.
2) For PATH-managed LSPs, set `mason = false` and use `vim.fn.exepath` in the server `cmd`.
3) Run the switch:
   - `scripts/clean-nvim-and-switch`
   - For Kotlin workspace generation:
     - `KOTLIN_LSP_PROJECT_ROOT=/path/to/project`
     - `KOTLIN_LSP_MODULE=app`
4) Verify:
   - `:LspInfo` shows the expected server attached.
   - Check `~/.local/state/nvim/lsp.log` for errors.

## Mason usage (exception only)
- Install manually with `:MasonInstall <tool>` when needed.
- If a tool becomes permanent, move it to Nix and remove Mason reliance.

## Kotlin-specific notes
- Kotlin LSP should resolve from PATH first; Mason fallback only.
- Ensure Java 17+, Gradle, and Android SDK are available.

## References
- `ANDROID_SUPPORT.md`
- `KOTLIN_ANDROID_WORKFLOW_PLAN.md`
