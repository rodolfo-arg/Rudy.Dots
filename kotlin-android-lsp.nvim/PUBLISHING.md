# Publishing kotlin-android-lsp.nvim

## Quick Steps

1. **Create GitHub repository**
   ```bash
   cd kotlin-android-lsp.nvim
   git init
   git add .
   git commit -m "Initial release: kotlin-android-lsp.nvim"
   ```

2. **Create repo on GitHub**
   - Go to https://github.com/new
   - Name: `kotlin-android-lsp.nvim`
   - Description: "Enhanced Kotlin/Android LSP support for Neovim with custom navigation for dependency sources"
   - Public repository
   - Don't add README (we have one)

3. **Push to GitHub**
   ```bash
   git remote add origin git@github.com:YOUR_USERNAME/kotlin-android-lsp.nvim.git
   git branch -M main
   git push -u origin main
   ```

4. **Create a release (optional but recommended)**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

   Or use GitHub's web interface:
   - Go to Releases → Create a new release
   - Tag: v1.0.0
   - Title: v1.0.0 - Initial Release
   - Add release notes

## Directory Structure

```
kotlin-android-lsp.nvim/
├── lua/
│   └── kotlin-android-lsp/
│       ├── init.lua          # Entry point
│       ├── config.lua        # Configuration
│       ├── uri.lua           # URI mapping
│       ├── attach.lua        # Auto-init & LSP control
│       ├── handlers.lua      # LSP handlers
│       ├── health.lua        # Health check
│       ├── indexer.lua       # Source indexer
│       ├── navigator.lua     # Custom navigation
│       ├── resolver.lua      # Symbol resolution
│       └── workspace.lua     # Workspace generation
├── scripts/
│   └── kotlin-lsp-workspace-json  # Workspace generator
├── doc/
│   └── kotlin-android-lsp.txt     # Vimdoc
├── README.md
├── LICENSE
└── PUBLISHING.md (this file)
```

## Users Can Install With

### lazy.nvim
```lua
{
  "YOUR_USERNAME/kotlin-android-lsp.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  ft = { "kotlin", "java" },
  config = function()
    require("kotlin-android-lsp").setup()
  end,
}
```

### packer.nvim
```lua
use {
  "YOUR_USERNAME/kotlin-android-lsp.nvim",
  requires = {
    "neovim/nvim-lspconfig",
    "nvim-treesitter/nvim-treesitter",
  },
  config = function()
    require("kotlin-android-lsp").setup()
  end,
}
```

### vim-plug
```vim
Plug 'YOUR_USERNAME/kotlin-android-lsp.nvim'
```

## Promoting Your Plugin

1. **Add topics to GitHub repo**:
   - neovim
   - neovim-plugin
   - kotlin
   - android
   - lsp

2. **Submit to awesome-neovim**:
   - Fork https://github.com/rockerBOO/awesome-neovim
   - Add entry under "Programming Languages Support > Kotlin"
   - Create PR

3. **Post on Reddit**:
   - r/neovim
   - r/androiddev
   - r/Kotlin

4. **Neovim Discourse**:
   - https://neovim.discourse.group/

## Maintenance

- Watch for issues on GitHub
- Keep dependencies updated
- Test with new Neovim releases
- Update for kotlin-lsp changes

## Version Bumping

```bash
# For bug fixes
git tag v1.0.1

# For new features
git tag v1.1.0

# For breaking changes
git tag v2.0.0

git push origin --tags
```
