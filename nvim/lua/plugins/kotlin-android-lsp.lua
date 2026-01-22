-- LazyVim plugin spec for kotlin-android-lsp
-- This loads our local plugin and configures LSP servers

return {
  -- Load our local kotlin-android-lsp plugin
  {
    dir = vim.fn.stdpath("config") .. "/lua/kotlin-android-lsp",
    name = "kotlin-android-lsp",
    lazy = false,
    priority = 100, -- Load before LSP configs
    config = function()
      require("kotlin-android-lsp").setup({
        default_module = "app",
        keymaps = {
          enabled = true,
          generate_workspace = "<leader>dk",
          workspace_info = "<leader>di",
        },
      })
    end,
  },

  -- nvim-jdtls for sophisticated Java LSP support
  -- Handles jdtls startup via ftplugin/java.lua
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    dependencies = {
      "neovim/nvim-lspconfig",
    },
  },

  -- Treesitter for Kotlin and Java
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      local langs = { "kotlin", "java", "groovy" } -- groovy for build.gradle
      for _, lang in ipairs(langs) do
        if not vim.tbl_contains(opts.ensure_installed, lang) then
          table.insert(opts.ensure_installed, lang)
        end
      end
      opts.auto_install = true
    end,
  },

  -- Kotlin LSP configuration
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- Resolve kotlin-lsp binary
      local function resolve_kotlin_lsp()
        local bin = vim.fn.exepath("kotlin-lsp")
        if bin ~= "" then
          return { bin }
        end
        local home = vim.env.HOME or vim.fn.expand("~")
        local nix_bin = home .. "/.nix-profile/bin/kotlin-lsp"
        if vim.fn.executable(nix_bin) == 1 then
          return { nix_bin }
        end
        local mason_bin = vim.fn.stdpath("data") .. "/mason/bin/kotlin-lsp"
        if vim.fn.executable(mason_bin) == 1 then
          return { mason_bin }
        end
        if vim.loop.fs_stat(mason_bin) then
          return { "bash", mason_bin }
        end
        return nil
      end

      local kotlin_lsp_cmd = resolve_kotlin_lsp() or { "kotlin-lsp" }
      local system_path = vim.fn.stdpath("cache") .. "/kotlin_lsp"

      -- Disable deprecated kotlin-language-server
      opts.servers.kotlin_language_server = { enabled = false }

      -- Configure kotlin_lsp
      opts.servers.kotlin_lsp = {
        cmd = vim.list_extend(vim.deepcopy(kotlin_lsp_cmd), {
          "--stdio",
          "--system-path",
          system_path,
        }),
        mason = false,
        filetypes = { "kotlin" },
        root_markers = {
          "workspace.json",
          "settings.gradle",
          "settings.gradle.kts",
          "build.gradle",
          "build.gradle.kts",
          "pom.xml",
          ".git",
        },
      }

      -- jdtls is now managed by nvim-jdtls via ftplugin/java.lua
      -- Disable lspconfig's jdtls to avoid conflicts
      opts.servers.jdtls = { enabled = false }
    end,
  },
}
