# Android/Kotlin LSP Support Notes

Date: 2026-01-22
Repo: `/Users/rodolfo/Rudy.Dots`

## Purpose
Track the Kotlin/Android LSP setup fixes, requirements, and current status so we can resume quickly later.

## Switch-first workflow (required)
- **After any config change**, run `scripts/clean-nvim-and-switch` before using Neovim.
- **Do not manually "reenable"** plugins or LSPs. The switch script bootstraps Lazy + Tree-sitter.
- Optional workspace generation (set before running the script):
  - `KOTLIN_LSP_PROJECT_ROOT=/path/to/project`
  - `KOTLIN_LSP_MODULE=app` (defaults to `app`)

## Requirements (current)
- **Neovim + LazyVim** (this repo manages config).
- **Kotlin LSP binary** available on PATH (Nix-first).
  - Mason install is a fallback only: `~/.local/share/nvim/mason/bin/kotlin-lsp`
- **Java 21+** (current kotlin-lsp build requires class file 65).
- **Gradle** available:
  - `./gradlew` in the project root **or** `gradle` on PATH.
- **Android SDK** available via `ANDROID_SDK_ROOT` or `ANDROID_HOME`:
  - Script uses the highest `platforms/android-*/android.jar`.
- **Python 3** (used by workspace generator).
- **Tree-sitter Kotlin parser** (auto-install enabled).
  - Tree-sitter CLI or a working compiler toolchain should be available.
- **unzip** available (zipPlugin uses it to open `zipfile://` jar sources).

## Hybrid Mason (Nix-first)
- Mason stays installed, but **auto-installs are disabled** to keep switches deterministic.
- Prefer Nix/Home Manager for LSP/DAP/formatter binaries on PATH.
- Use Mason only for short-lived testing or when nixpkgs lacks a tool.
- Full workflow details: `HYBRID_MASON_MIGRATION.md`.

## Key Commands
- Switch + bootstrap (required after config changes):
  ```bash
  scripts/clean-nvim-and-switch
  ```
- Switch + bootstrap + regenerate workspace files:
  ```bash
  KOTLIN_LSP_PROJECT_ROOT=~/AndroidStudioProjects/kotlinpractice1 \
  KOTLIN_LSP_MODULE=app \
  scripts/clean-nvim-and-switch
  ```
- Generate Kotlin LSP workspace files (run from anywhere):
  ```bash
  ~/Rudy.Dots/scripts/kotlin-lsp-workspace-json ~/AndroidStudioProjects/kotlinpractice1 app
  ```
  Outputs:
  - `<project>/workspace.json`
  - `<project>/kotlin-lsp-config.json`

- Restart Kotlin LSP in Neovim:
  - `:LspStop` then `:LspStart kotlin_lsp` (or restart nvim).
  - Use only for debugging; fixes must be encoded in repo + switch.

- LSP log tail:
  ```bash
  tail -n 80 ~/.local/state/nvim/lsp.log
  ```
- LSP log tail (kotlin-lsp focused):
  ```bash
  rg -n "kotlin-lsp|workspace.json|Error parsing" ~/.local/state/nvim/lsp.log | tail -n 80
  ```
- Quick workspace.json sanity check:
  ```bash
  rg -n 'DEFAULT|COMPILE|ROOT_ITSELF|"value"' <project>/workspace.json
  ```
- Ensure Tree-sitter Kotlin parser is installed:
  - **Handled by** `scripts/clean-nvim-and-switch`.

## Official Kotlin LSP (JetBrains) - Correct Setup Notes
Source: https://github.com/Kotlin/kotlin-lsp
- **Pre-alpha**; stability is not guaranteed. Expect breaking changes.
- **Java 17+** is required by the upstream CLI. (Our current binary needs Java 21.)
- **Out-of-the-box support is JVM-only Kotlin Gradle projects**.
- **JSON-based import** is supported for non-Gradle or custom setups (see `workspace-import` in the repo).
- **Other editors must be manually configured** and must support *pull-based diagnostics*.
- **Install CLI**:
  - `brew install JetBrains/utils/kotlin-lsp`
  - or download the standalone zip, `chmod +x kotlin-lsp.sh`, and symlink it into PATH.

## Alternate Kotlin LSPs (community / legacy)
- **amgdev9/kotlin-lsp** (community, Kotlin Analysis API based):
  - Supports Gradle (single & multi-module) and **single-module Android** (debug variant only).
  - **Does not handle** Android source set merging; **multimodule Android** and **KMP** still need work.
  - File-based mode uses `.kotlinlsp-modules.json`.
- **fwcd/kotlin-language-server** (legacy):
  - **Deprecated** in favor of the official Kotlin LSP.

## History of Changes
### 0) Jar sources working in Neovim
Files: `nvim/lua/config/lazy.lua`, `nvim/lua/plugins/lsp.lua`
- Re-enabled `zipPlugin` so Neovim can open `zipfile://` buffers.
- Map `jar:` URIs from the LSP to `zipfile://...::` (zipPlugin format).
- Strip leading `/` from inner paths to avoid empty buffers.

### 1) Kotlin LSP workspace generator fixes
File: `scripts/kotlin-lsp-workspace-json`
- **Fixed dependency shape**: removed `value` wrapper in dependencies.
- **Fixed enum values**:
  - Dependency scopes now use lower-case serial names: `compile`, `test`, `runtime`, `provided`.
  - `inclusionOptions` now uses `root_itself` (lower-case serial name).
- **Ensures Android SDK jar** gets added to `compile` scope.
- **Keeps AAR handling**:
  - Extracts `classes.jar` from AARs into `~/.cache/kotlin-lsp/aar-classes/`.
  - Attaches `-sources.jar` when present.
- **Normalizes paths** to `<WORKSPACE>` and `<HOME>` for portability.

### 2) Kotlin LSP startup robustness
File: `nvim/lua/plugins/kotlin.lua`
- **Reliable command resolution**:
  - Prefer `exepath("kotlin-lsp")`.
  - Fallback to Mason binary.
  - If Mason script exists but is not executable, run it via `bash`.
- **Explicit LSP args**:
  - `--stdio` + `--system-path <cache>/kotlin_lsp`.
- **Disable Mason gating** for kotlin_lsp (`mason = false`) so LSP can start even if Mason metadata is off.
- **Root detection** uses `workspace.json` first, then Gradle/pom/.git.

### 3) Treesitter Kotlin parser reliability
File: `nvim/lua/plugins/kotlin.lua`
- Treesitter is **eager-loaded** (`lazy = false`).
- `kotlin` added to `ensure_installed`.
- `auto_install = true` to avoid manual TS installs.
- TS commands are now registered (`TSInstall`, `TSInstallSync`, `TSInstallInfo`, `TSUpdate`).

### 4) LazyVim extras cleanup to reduce Mason errors
File: `nvim/lua/config/lazy.lua`
- Removed extra language packs that caused Mason issues:
  - `astro`, `angular`, `nix` extras removed.
- This prevents the “astro-language-server path not found” and `nil_ls`/cargo errors.

### 5) Clean + switch script updated
File: `scripts/clean-nvim-and-switch`
- `home-manager switch` now runs with `--impure`.

### 6) Kotlin settings enum fix
File: `scripts/kotlin-lsp-workspace-json`
- `kotlinSettings[0].kind` now uses lower-case `default`.

### 7) Disable kotlin-language-server (force kotlin_lsp)
Files: `nvim/lua/plugins/kotlin.lua`, `nvim/lua/plugins/mason.lua`
- Explicitly disables `kotlin_language_server`.
- Removes `kotlin_language_server` from Mason ensure list.

### 8) Bidirectional URI mapping for jar sources
File: `nvim/lua/plugins/lsp.lua`
- Added `vim.uri_from_fname` override to convert `zipfile://` paths back to `jar:` URIs.
- This enables LSP requests from jar source buffers to use the correct URI format.
- Works with the existing `vim.uri_to_fname` override (jar: → zipfile://).

### 9) Android SDK sources support
File: `scripts/kotlin-lsp-workspace-json`
- Added `best_android_jar_and_sources()` to find both android.jar and matching sources.
- Prefers API level with available sources over highest API without sources.
- Creates a sources jar from the SDK sources directory (`~/.cache/kotlin-lsp/android-sources/`).
- Android SDK sources (e.g., `android-34-sources.jar`) are now included in workspace.json.

### 10) LSP attachment for jar source buffers
File: `nvim/lua/plugins/kotlin.lua`
- Extended autocmd to handle both Kotlin and Java files in zipfile buffers.
- Added explicit `textDocument/didOpen` notification with correct jar: URI.
- Uses both `FileType` and `BufReadPost` events for reliable attachment.
- Enables LSP features (go-to-definition, hover) inside dependency sources.

## Achievements / Current State
- Kotlin LSP now **starts successfully** and stays active in Neovim.
- `gd` now opens jar sources (e.g., JUnit) via `zipfile://...::`.
- **Bidirectional URI mapping**: jar: ↔ zipfile:// for LSP communication.
- **Android SDK sources**: Now packaged and included in workspace.json.
- **LSP attaches to jar source buffers**: Both Kotlin and Java files get LSP features.
- Workspace generator now matches kotlin-lsp JSON schema (no unknown keys, correct enums).
- Treesitter Kotlin parser auto-install is enabled (reduces manual TS setup).
- kotlin-language-server is disabled to prevent conflicts.
- Reduced Mason noise by removing extras that depend on node/cargo.

## Known Issues / Watchpoints
- **Navigation inside jar sources (second-level)**: Confirmed limitation. Kotlin LSP indexes
  Java sources for Kotlin→Java navigation but does not fully index Java files for Java→Java
  navigation within libraries. Potential workaround: use jdtls (Eclipse Java LSP) for Java files.
- **Multiple editing sessions** error: If you see "Multiple editing sessions for one workspace
  are not supported yet", kill all kotlin-lsp processes and clear `~/.cache/nvim/kotlin_lsp`.
- If SDK or dependency sources are missing, go-to-definition may open decompiled/binary text.
- If `workspace.json` is **not regenerated** after script changes, LSP can still fail with:
  - unknown keys (e.g., `value`)
  - invalid enum values (`COMPILE`, `ROOT_ITSELF`)
- `kotlin-lsp` warnings about `sun.awt.*` are **harmless**.
- If definitions still fail, re-run the generator and restart LSP.
- Official Kotlin LSP is **pre-alpha** and only supports **JVM-only Gradle** projects out-of-the-box.
- Kotlin LSP requires **Java 17+** and **pull-based diagnostics** support from the editor.
- If `:TSInstallInfo` is missing after a switch, rerun `scripts/clean-nvim-and-switch`
  (it bootstraps Lazy and installs the Kotlin Tree-sitter parser).

## Source Artifacts & Size Guidance
- **Android SDK sources** are installed per API level (tens of MB each). Install only the API levels you compile against.
- **Gradle dependency sources** are cached per-user in `~/.gradle/caches/modules-2/files-2.1` and shared across projects.

## Plan (Delegate / Builder)
Phase 0 — Prereqs (one-time machine setup)
- Ensure `JAVA_HOME` points at JDK 21.
- Ensure `ANDROID_SDK_ROOT` (or `ANDROID_HOME`) is set and points to the shared SDK.
- Ensure `kotlin-lsp` is on PATH (from Nix profile).

Phase 1 — Android SDK sources
- Install **Sources** for the project’s `compileSdk` (and any other API levels actually used).
- Verify `platforms;android-XX` and `sources;android-XX` exist in the SDK.

Phase 2 — Dependency sources (JUnit/Hamcrest/etc.)
- Verify test deps are declared in the correct source set (`testImplementation` / `androidTestImplementation`).
- Confirm `*-sources.jar` exists in `~/.gradle/caches/modules-2/files-2.1/…`.
- If missing, trigger a Gradle refresh to download sources.

Phase 3 — Regenerate Kotlin LSP workspace
- Run:
  ```bash
  KOTLIN_LSP_PROJECT_ROOT=~/AndroidStudioProjects/kotlinpractice1 \
  KOTLIN_LSP_MODULE=app \
  scripts/clean-nvim-and-switch
  ```

Phase 4 — Verification
- In Neovim, confirm `gd` opens readable source for:
  - `android.*` (e.g., `Instrumentation`, `Bundle`)
  - `InstrumentationRegistry.getInstrumentation().targetContext`
  - JUnit/Hamcrest classes listed in test imports
- If any open “gibberish”, capture `:echo bufname('%')` and the missing dependency coordinate.

## Next Checks if Definitions Still Fail
1) Confirm latest workspace.json:
   - No `value` key in dependencies.
   - `scope` values are `compile/test/runtime/provided`.
   - `inclusionOptions` is `root_itself`.
   - `kotlinSettings[0].kind` is `default`.
2) Restart LSP and check log tail.
3) Ensure Android SDK env vars are set.
4) Ensure the last change included a `scripts/clean-nvim-and-switch`.
5) Verify only `kotlin_lsp` is attached (`:LspInfo`).

## Plan: jdtls for Java Navigation in Jar Sources

### Problem Statement
Kotlin LSP indexes Java sources for Kotlin→Java navigation but does not support Java→Java
navigation within library sources. To enable full multi-layer navigation, we need jdtls
(Eclipse Java LSP) to handle Java files in jar sources.

### Phase 0 — Research & Prerequisites ✓
**Goal**: Understand jdtls requirements and compatibility with our setup.
- [x] Review jdtls documentation for single-file/library mode support
- [x] Check if jdtls can attach to virtual buffers (zipfile://)
- [x] Identify jdtls installation method (Nix preferred, Mason fallback)
- [x] Determine if jdtls needs a project context or can work standalone

**Findings**:
1. **jdtls requires project context**: Without proper project detection (Gradle/Maven),
   jdtls only provides syntax highlighting and JDK class assistance—not full navigation.
   Source: [eclipse-jdtls/eclipse.jdt.ls](https://github.com/eclipse-jdtls/eclipse.jdt.ls)

2. **jdtls uses jdt:// URI scheme**: For decompiled/attached sources, jdtls uses its own
   URI scheme (`jdt://contents/...`), NOT `jar:` or `zipfile://`. This is incompatible
   with kotlin-lsp's approach. Source: [helix-editor issue #11559](https://github.com/helix-editor/helix/issues/11559)

3. **Source attachment is possible**: Via `java.project.referencedLibraries` setting with
   explicit source mappings. jdtls will then use attached sources for navigation.
   Source: [VS Code Java docs](https://code.visualstudio.com/docs/java/java-project)

4. **nvim-jdtls is the recommended plugin**: Handles jdt:// URI content provider and
   jdtls-specific features. Requires Java 21+.
   Source: [mfussenegger/nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)

5. **Installation options**: Nix (`jdt-language-server`), Mason, or manual download.

**Revised approach**:
- Use jdtls for Java files in the Android project (test files, build files)
- jdtls will auto-detect Gradle project and configure classpath
- When navigating from Java files, jdtls provides its own source navigation
- kotlin-lsp handles Kotlin files; jdtls handles Java files (separate LSPs)
- Cross-LSP navigation: Kotlin→Java (kotlin-lsp), Java→Java (jdtls)

### Phase 1 — jdtls Installation ✓
**Goal**: Make jdtls available on PATH.
- [x] Add jdtls to Nix flake or home-manager config
- [x] Verify jdtls binary works: `jdtls --version` or equivalent
- [x] Document Java version requirements (jdtls typically needs Java 17+)

**Implementation**:
- Added `jdt-language-server` to flake.nix packages
- Installed at `~/.nix-profile/bin/jdtls`
- Requires Java 21+ (same as kotlin-lsp)

### Phase 2 — Basic jdtls Configuration ✓
**Goal**: Configure jdtls for normal Java project files.
- [x] Create jdtls server config in kotlin-android-lsp plugin
- [x] Configure root detection (build.gradle, pom.xml, .git)
- [x] jdtls and kotlin_lsp configured separately for their filetypes

### Phase 3 — jdtls for Zipfile Buffers ✓
**Goal**: Attach jdtls to Java files inside jar sources.
- [x] Extend zipfile autocmd to attach both kotlin_lsp and jdtls to Java buffers
- [x] URI translation handled in kotlin-android-lsp/uri.lua
- [x] didOpen notification sent via kotlin-android-lsp/attach.lua

### Phase 4 — Navigation Testing
**Goal**: Verify multi-layer Java navigation works.
- [ ] Test gd on `android.app.Instrumentation` → opens source
- [ ] Test gd inside `Instrumentation.java` on internal references
- [ ] Verify hover, references, and other LSP features work
- [ ] Document any limitations or edge cases
- **Note**: Second-layer Java→Java navigation may still be limited by jdtls project context

### Phase 5 — Polish & Documentation ✓
**Goal**: Finalize the setup and document.
- [x] Created kotlin-android-lsp plugin (extractable for community use)
- [x] Added <leader>dk and <leader>di keymaps
- [x] Added :KotlinWorkspaceGenerate and :KotlinWorkspaceInfo commands
- [x] Added :checkhealth kotlin-android-lsp

### Risks & Considerations
- jdtls may require a proper Java project context, not just loose files
- jdtls workspace/project detection may conflict with zipfile:// paths
- Memory usage: running two LSPs (kotlin_lsp + jdtls) increases footprint
- URI format differences between jdtls and kotlin-lsp may need handling

## kotlin-android-lsp Plugin

A local Neovim plugin for Kotlin/Android LSP support, designed to be extractable for community use.

### Plugin Structure
```
nvim/lua/kotlin-android-lsp/
├── init.lua      # Main entry, setup(), commands, keymaps
├── config.lua    # Configuration with defaults
├── uri.lua       # Bidirectional jar:/zipfile:// URI mapping
├── attach.lua    # LSP attachment for jar source buffers
├── workspace.lua # Workspace generation, project detection
└── health.lua    # :checkhealth kotlin-android-lsp
```

### Commands
- `:KotlinWorkspaceGenerate [path]` - Generate workspace.json for project
- `:KotlinWorkspaceInfo` - Show workspace information in floating window

### Keymaps (default)
- `<leader>dk` - Generate workspace.json for current directory
- `<leader>di` - Show workspace info

### Project Type Detection
The plugin parses `build.gradle`/`build.gradle.kts` to detect:
- **Android**: `android {}` block or `com.android` plugin
- **Kotlin JVM**: `kotlin("jvm")` or `org.jetbrains.kotlin` plugin
- **Java**: `java` plugin
- **Mixed**: Both Kotlin and Java sources

### Supported Project Types
- Android (single/multi-module)
- Kotlin JVM
- Pure Java
- Mixed Kotlin + Java

## Community Plugins / "IDE-like" Add-ons
- **LazyVim Kotlin extra** bundles:
  - `nvim-treesitter` (syntax highlighting),
  - `ktlint` for lint/format (via `nvim-lint`, `conform.nvim`, or `none-ls`),
  - `nvim-dap` wiring for `kotlin-debug-adapter`.
- **kotlin-debug-adapter** (DAP) adds Kotlin/JVM debugging support; works with any DAP client.
