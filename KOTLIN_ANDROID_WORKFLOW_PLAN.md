# Kotlin/Android Workflow Plan (Switch-First)

Date: 2026-01-21
Repo: /Users/rodolfo/Rudy.Dots

## Goals
- Keep /Users/rodolfo/Rudy.Dots as the single source of truth for Neovim/LazyVim and Kotlin/Android LSP setup.
- Require a switch after every config change; avoid manual re-enabling or ad-hoc fixes.
- Ensure Kotlin LSP can index project code and dependencies reliably.
- Automate repeatable steps in repo scripts/config.
- Prefer Nix/Home Manager for tool installation; keep Mason available but disable auto-installs.

## Preconditions (must be true)
- Java 17+ installed and on PATH.
- Gradle available via project ./gradlew or system gradle.
- Android SDK available via ANDROID_SDK_ROOT or ANDROID_HOME.
- Kotlin LSP binary available on PATH (Nix-first); Mason bin is fallback only.
- Python 3 available (workspace generator uses it).

## Required workflow (every change)
1) Make edits only in /Users/rodolfo/Rudy.Dots (no direct edits under ~/.config/nvim or other generated paths).
2) Run the switch script:
   - `scripts/clean-nvim-and-switch`
3) Open Neovim and verify:
   - `:LspInfo` shows only `kotlin_lsp` attached.
   - Kotlin tree-sitter parser is present (commands exist).
4) If changes are not effective, update repo config/scripts and repeat the switch.

## Hybrid Mason (Nix-first)
- Mason stays installed, but **auto-installs are disabled** to keep switches deterministic.
- Prefer Nix/Home Manager for LSP/DAP/formatter binaries on PATH.
- Use Mason only for short-lived testing or when nixpkgs lacks a tool.
- Details and steps: `HYBRID_MASON_MIGRATION.md`.

## Workspace generation (automated)
Use the switch script to generate `workspace.json` and `kotlin-lsp-config.json` when needed:
- `KOTLIN_LSP_PROJECT_ROOT=/path/to/project`
- `KOTLIN_LSP_MODULE=app` (default)
- Then run `scripts/clean-nvim-and-switch`

Expected outputs:
- `<project>/workspace.json`
- `<project>/kotlin-lsp-config.json`

## Treesitter setup (automated)
- `scripts/clean-nvim-and-switch` must bootstrap Lazy plugins and install the Kotlin parser.
- Do not run `:TSInstallSync` as a primary fix; encode the behavior in the switch script.

## Kotlin LSP setup (config-driven)
- `kotlin_language_server` must remain disabled.
- `kotlin_lsp` must resolve from PATH or Mason bin (prefer PATH).
- LSP root detection uses `workspace.json` first, then Gradle files.

## Verification checklist (post-switch)
- `:LspInfo` shows `kotlin_lsp` attached to Kotlin buffers.
- `workspace.json` has:
  - `scope` values: `compile`, `test`, `runtime`, `provided`
  - `inclusionOptions`: `root_itself`
  - `kotlinSettings[0].kind`: `default`
  - no `value` wrapper in dependencies
- LSP log contains no schema or parsing errors:
  - `tail -n 80 ~/.local/state/nvim/lsp.log`
  - `rg -n "kotlin-lsp|workspace.json|Error parsing" ~/.local/state/nvim/lsp.log | tail -n 80`

## Troubleshooting loop (switch-first)
1) Regenerate workspace via switch (set env vars, re-run `scripts/clean-nvim-and-switch`).
2) Verify Android SDK env vars are set and `android.jar` is available.
3) Confirm Kotlin LSP binary resolution (PATH or Mason bin).
4) Review LSP log for schema errors and fix generator/config accordingly.
5) Switch again.

## Known issues (recorded)
- `E492: Not an editor command: TSInstallSync kotlin` means treesitter commands were not loaded; fix is to ensure bootstrap during switch.
- Workspace JSON schema mismatches break Kotlin LSP (enum casing, missing keys, `value` wrapper).
- Extra LazyVim language packs previously caused Mason path errors (keep removed unless intentionally reintroduced).
- Kotlin LSP is pre-alpha and JVM-only Gradle support is limited.

## Ongoing maintenance
- Any manual workaround must be converted into config or scripts and committed to this repo.
- After every config update, re-run `scripts/clean-nvim-and-switch` before testing.
- Document new regressions and fixes in ANDROID_SUPPORT.md.
