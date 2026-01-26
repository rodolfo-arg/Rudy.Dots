# kotlin-android-lsp.nvim

Enhanced Kotlin/Android/Java LSP support for Neovim with **custom navigation for dependency sources**.

## Features

- **Auto-build on open**: Automatically runs `./gradlew assembleDebug` when needed
- **Workspace generation**: Creates `workspace.json` for kotlin-lsp with all dependencies
- **Custom navigation**: `gd`/`gr`/`K` work inside JAR/AAR source files
- **Source indexing**: Lazy indexes JDK, Android SDK, and Gradle dependencies
- **Generated sources**: Includes Data Binding, View Binding, R class in workspace
- **LSP control**: Disables LSP errors on read-only dependency sources

## Requirements

- Neovim 0.10+
- Java 21+
- [kotlin-lsp](https://github.com/AerialFR/kotlin-lsp) (JetBrains Kotlin LSP)
- Python 3 (for workspace generation)
- Treesitter parsers: `kotlin`, `java`, `groovy`

### Optional

- jdtls (for Java files)
- Android SDK with sources

## Installation

### lazy.nvim

```lua
{
  "yourusername/kotlin-android-lsp.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  ft = { "kotlin", "java" },
  config = function()
    require("kotlin-android-lsp").setup({
      default_module = "app",
    })
  end,
}
```

### packer.nvim

```lua
use {
  "yourusername/kotlin-android-lsp.nvim",
  requires = {
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  ft = { "kotlin", "java" },
  config = function()
    require("kotlin-android-lsp").setup()
  end,
}
```

## Setup

### 1. Install kotlin-lsp

```bash
# Via Nix
nix profile install github:AerialFR/kotlin-lsp

# Or build from source
git clone https://github.com/AerialFR/kotlin-lsp
cd kotlin-lsp && ./gradlew installDist
```

### 2. Configure LSP

Add to your LSP configuration:

```lua
local lspconfig = require("lspconfig")

lspconfig.kotlin_lsp.setup({
  cmd = { "kotlin-lsp", "--stdio" },
  filetypes = { "kotlin" },
  root_dir = lspconfig.util.root_pattern(
    "workspace.json",
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts"
  ),
})
```

### 3. Install Treesitter parsers

```vim
:TSInstall kotlin java groovy
```

## Usage

### Automatic Flow

1. Open a Kotlin file in an Android/Gradle project
2. Plugin detects if build is needed (checks for R.jar)
3. If needed, runs `./gradlew assembleDebug` automatically
4. Generates `workspace.json` and restarts LSP
5. Indexes dependency sources for custom navigation

### Commands

| Command | Description |
|---------|-------------|
| `:KotlinWorkspaceGenerate` | Generate workspace.json |
| `:KotlinWorkspaceInfo` | Show project info |
| `:KotlinAssembleDebug` | Run Gradle build |
| `:KotlinRefresh` | Rebuild + regenerate + restart LSP |
| `:KotlinIndexSources` | Manually trigger indexing |
| `:KotlinStatus` | Show indexing status |

### Keymaps

| Keymap | Description |
|--------|-------------|
| `<leader>dk` | Generate workspace |
| `<leader>di` | Show workspace info |
| `<leader>da` | Run assembleDebug |
| `gd` | Go to definition (custom for zipfile buffers) |
| `gr` | Find references (custom for zipfile buffers) |
| `K` | Show symbol info (custom for zipfile buffers) |

## Configuration

```lua
require("kotlin-android-lsp").setup({
  -- Default Gradle module to use
  default_module = "app",

  -- Path to workspace generator script (nil = use bundled)
  workspace_script = nil,

  -- Cache directory
  cache_dir = vim.fn.stdpath("cache") .. "/kotlin-android-lsp",

  -- Keymap configuration
  keymaps = {
    enabled = true,
    generate_workspace = "<leader>dk",
    workspace_info = "<leader>di",
  },

  -- Kotlin LSP settings
  kotlin_lsp = {
    enabled = true,
    cmd = nil,  -- Auto-detect
  },

  -- jdtls settings
  jdtls = {
    enabled = true,
    cmd = nil,  -- Auto-detect
  },

  -- Android SDK settings
  android = {
    sdk_root = vim.env.ANDROID_SDK_ROOT or vim.env.ANDROID_HOME,
    prefer_sources_api = true,
  },
})
```

## How It Works

### Workspace Generation

The plugin runs a Gradle task to extract the classpath:

1. Injects a custom Gradle init script
2. Runs `:module:klsClasspath` to get all dependencies
3. Parses output to build `workspace.json` with:
   - Source roots (src/main/kotlin, src/main/java)
   - Generated sources (data binding, view binding)
   - Dependencies (JARs, AARs with sources)
   - R.jar for resource references

### Custom Navigation

For dependency sources (`zipfile://` buffers):

1. **Symbol resolution**: Uses Treesitter to parse imports and resolve symbols to FQNs
2. **Index lookup**: Searches indexed JARs for matching FQN
3. **Navigation**: Opens the zipfile buffer at the correct location

### Source Indexing

Indexes sources lazily with disk caching:

- **JDK**: `$JAVA_HOME/lib/src.zip`
- **Android SDK**: `$ANDROID_HOME/sources/android-XX/`
- **Gradle**: All `*-sources.jar` in `~/.gradle/caches/`

## Troubleshooting

### Health Check

```vim
:checkhealth kotlin-android-lsp
```

### Common Issues

**"Unresolved reference 'R'"**
- Run `:KotlinAssembleDebug` to build the project
- Run `:KotlinWorkspaceGenerate` to regenerate workspace

**LSP errors in dependency sources**
- These are automatically disabled for zipfile buffers
- If still appearing, run `:KotlinRefresh`

**Navigation not working in JARs**
- Check indexing status: `:KotlinStatus`
- Manually trigger: `:KotlinIndexSources`
- Clear cache: `:KotlinClearCache`

**Build fails**
- Errors shown in floating window
- Check with: `./gradlew assembleDebug` in terminal

### Debug Logging

```vim
:lua vim.lsp.set_log_level("DEBUG")
:e ~/.local/state/nvim/lsp.log
```

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License - see [LICENSE](LICENSE)

## Credits

- [JetBrains](https://github.com/AerialFR/kotlin-lsp) for kotlin-lsp
- [Eclipse Foundation](https://github.com/eclipse/eclipse.jdt.ls) for jdtls
- Neovim team for LSP and treesitter
