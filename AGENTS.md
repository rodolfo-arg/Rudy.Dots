# AGENTS

Last updated: 2026-01-22

## Workflow rules
- **Commit and push after each change**: After completing a logical change or fix, commit and push to remote. This ensures work is preserved and reviewable incrementally.

## Important notes
- nvim-treesitter must not be lazy-loaded; avoid `cmd` triggers in its spec and keep `lazy = false`.
- Headless switches should install the Kotlin parser via the Lua API:
  `require('nvim-treesitter').install({ 'kotlin' }):wait(300000)`.
  `TSInstallSync` can fail if commands are not registered during startup.
- Switch workflow remains mandatory: run `scripts/clean-nvim-and-switch` after changes.
- Kotlin LSP workspace generation is skipped unless `KOTLIN_LSP_PROJECT_ROOT` is set.
- Kotlin LSP resolver falls back to `~/.nix-profile/bin/kotlin-lsp` to avoid GUI PATH issues.
- Kotlin LSP uses a wrapper script to run system Java; bundled JRE in the zip is read-only in the Nix store.
- Kotlin LSP currently requires Java 21 (class file version 65); the wrapper points at a JDK 21 binary.
- Zip/jar support must stay enabled (do not disable `zipPlugin`) so LSP can open `jar:` sources.
- Neovim maps `jar:` URIs to `zipfile://...::/` so definitions in jars open correctly.
- When mapping `jar:` URIs, strip any leading `/` from the inner path; `zipPlugin` fails to extract with a leading slash.
- Kotlin LSP Android support is limited (single-module debug variant; test/androidTest source sets may be unresolved).
- Kotlin LSP may fall back to decompiled class files when sources for JDK/SDK/deps are missing.
- Hybrid Mason stays in place: Mason is installed but auto-installs are disabled; PATH-first LSPs.
