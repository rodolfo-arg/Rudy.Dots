# Kotlin Android LSP - Implementation Summary

**Date:** 2026-01-22
**Author:** Rodolfo (with Claude Code assistance)

## Overview

A comprehensive Neovim plugin that provides enhanced Kotlin/Android/Java LSP support with custom navigation for dependency sources. Solves the problem of navigating into and within JAR/AAR dependencies that standard LSP servers don't handle well.

## Problem Statement

Standard Kotlin LSP (`kotlin-lsp` from JetBrains) provides good navigation for project source files but struggles with:
1. **Second-layer navigation**: After jumping into a dependency source (e.g., `Activity.java`), further navigation within that file doesn't work
2. **URI scheme incompatibility**: kotlin_lsp uses `jar:` URIs, jdtls uses `jdt:` URIs, Neovim's zipPlugin uses `zipfile://`
3. **Missing generated sources**: Data Binding classes (`*Binding`), R class, BuildConfig not indexed
4. **Manual workspace setup**: Requires manual `workspace.json` generation

## Solution Architecture

### Core Components

| Module | Purpose |
|--------|---------|
| `init.lua` | Entry point, setup(), user commands, keymaps |
| `config.lua` | Configuration with sensible defaults |
| `uri.lua` | Bidirectional `jar:` ↔ `zipfile://` URI mapping |
| `attach.lua` | Auto-build, workspace generation, LSP attachment control |
| `handlers.lua` | Custom LSP handlers for `jdt://` URI conversion |
| `indexer.lua` | Lazy JAR indexer with disk cache (FQN → zipfile path) |
| `navigator.lua` | Custom `gd`/`gr`/`K` handlers for zipfile buffers |
| `resolver.lua` | Treesitter-based symbol → FQN resolution |
| `workspace.lua` | Gradle project detection and workspace.json generation |
| `health.lua` | `:checkhealth` integration |

### External Script

| Script | Purpose |
|--------|---------|
| `kotlin-lsp-workspace-json` | Bash/Python script that runs Gradle to extract classpath and generates `workspace.json` |

## Key Features

### 1. Automatic Project Initialization

When opening a Kotlin file in a Gradle project:
1. **Build detection**: Checks if `R.jar` exists (indicates previous build)
2. **Auto-build**: Runs `./gradlew assembleDebug` if needed
3. **Workspace generation**: Creates `workspace.json` with all dependencies
4. **LSP restart**: Automatically restarts `kotlin_lsp` to pick up new configuration
5. **Source indexing**: Indexes JDK, Android SDK, and Gradle dependencies for custom navigation

### 2. Custom Navigation for Dependency Sources

For `zipfile://` buffers (JAR/AAR sources):
- **LSP disabled**: Prevents kotlin_lsp/jdtls errors on read-only sources
- **Diagnostics disabled**: No spurious errors in dependency code
- **Custom `gd`**: Treesitter-based symbol resolution + FQN index lookup
- **Custom `gr`**: Grep-based reference search within JAR
- **Custom `K`**: Shows resolved FQN and index location

### 3. Lazy Source Indexing

Indexes sources on-demand with disk caching:
- **JDK**: `src.zip` from Java installation
- **Android SDK**: `sources/android-XX/` directory
- **Gradle dependencies**: All `*-sources.jar` from `~/.gradle/caches`
- **Cache**: JSON files in `~/.cache/nvim/kotlin-android-lsp/indexes/`

### 4. Generated Sources Support

Workspace includes generated code:
- `build/generated/data_binding_base_class_source_out/debug/out/` (Data Binding)
- `build/generated/ap_generated_sources/debug/out/` (View Binding, annotation processing)
- `build/intermediates/compile_and_runtime_not_namespaced_r_class_jar/debug/.../R.jar` (R class)

## User Commands

| Command | Description |
|---------|-------------|
| `:KotlinWorkspaceGenerate` | Generate `workspace.json` for current project |
| `:KotlinWorkspaceInfo` | Show project info in floating window |
| `:KotlinAssembleDebug` | Run `./gradlew assembleDebug` |
| `:KotlinRefresh` | Rebuild + regenerate workspace + restart LSP |
| `:KotlinIndexSources` | Manually trigger source indexing |
| `:KotlinStatus` | Show indexing status (not_started/in_progress/complete) |
| `:KotlinLookup <fqn>` | Debug: lookup FQN in index |
| `:KotlinShowImports` | Debug: show parsed imports for current buffer |
| `:KotlinClearCache` | Clear index cache |

## Keymaps

| Keymap | Description |
|--------|-------------|
| `<leader>dk` | Generate Kotlin workspace |
| `<leader>di` | Show workspace info |
| `<leader>da` | Run assembleDebug |
| `gd` (zipfile buffers) | Custom go-to-definition |
| `gr` (zipfile buffers) | Custom find references |
| `K` (zipfile buffers) | Show symbol info |

## Configuration

```lua
require("kotlin-android-lsp").setup({
  default_module = "app",  -- Default Gradle module
  keymaps = {
    enabled = true,
    generate_workspace = "<leader>dk",
    workspace_info = "<leader>di",
  },
  android = {
    sdk_root = vim.env.ANDROID_SDK_ROOT or vim.env.ANDROID_HOME,
    prefer_sources_api = true,
  },
})
```

## Dependencies

### Required
- **Neovim 0.10+** (for treesitter and LSP improvements)
- **Java 21+** (for kotlin-lsp and jdtls)
- **kotlin-lsp** (JetBrains Kotlin LSP)
- **Treesitter parsers**: `kotlin`, `java`, `groovy`
- **Python 3** (for workspace generation script)

### Optional
- **jdtls** (Eclipse Java LSP, for Java files)
- **Android SDK with sources** (for Android SDK navigation)

## Flow Diagrams

### Project Initialization
```
Open .kt file
    │
    ├─► Is Gradle project? ──No──► Skip
    │
    ▼ Yes
Check for R.jar
    │
    ├─► Exists ──► Generate workspace.json (if missing)
    │              └─► Index sources
    │
    ▼ Missing
Run ./gradlew assembleDebug
    │
    ├─► Success ──► Generate workspace.json
    │              └─► Restart kotlin_lsp
    │              └─► Index sources
    │
    ▼ Failure
Show errors in floating window
```

### Navigation in Dependency Sources
```
User presses gd on symbol
    │
    ▼
Treesitter: get symbol under cursor
    │
    ▼
Resolver: parse imports, resolve to FQN candidates
    │
    ▼
Indexer: lookup each FQN candidate
    │
    ├─► Found ──► Open zipfile:// buffer
    │
    ▼ Not found
Index additional packages
    │
    ├─► Found ──► Open zipfile:// buffer
    │
    ▼ Not found
Show "Definition not found" message
```

## File Locations

```
~/.config/nvim/lua/kotlin-android-lsp/
├── init.lua          # Entry point
├── config.lua        # Configuration
├── uri.lua           # URI mapping
├── attach.lua        # Auto-init & LSP control
├── handlers.lua      # LSP handlers
├── indexer.lua       # Source indexer
├── navigator.lua     # Custom navigation
├── resolver.lua      # Symbol resolution
├── workspace.lua     # Workspace generation
└── health.lua        # Health check

~/Rudy.Dots/scripts/
└── kotlin-lsp-workspace-json  # Workspace generator

~/.cache/nvim/kotlin-android-lsp/
└── indexes/          # Cached jar indexes
```

## Known Limitations

1. **Build required**: Project must be built at least once for R class and data binding
2. **Single module focus**: Workspace generation focuses on one Gradle module at a time
3. **No cross-JAR references**: `gr` only searches within current JAR
4. **No rename/refactor**: Custom navigator is read-only
5. **Kotlin-first**: Custom navigation optimized for Kotlin→Java, Java→Java paths

## Future Improvements

- [ ] Multi-module workspace support
- [ ] Incremental workspace updates (detect new dependencies)
- [ ] Cross-JAR reference search
- [ ] Integration with quickfix for build errors
- [ ] Support for Kotlin Multiplatform projects
- [ ] Better handling of nested/inner classes

## Credits

- **JetBrains** for kotlin-lsp
- **Eclipse Foundation** for jdtls
- **Neovim team** for LSP and treesitter infrastructure
- **Claude Code** (Anthropic) for implementation assistance
