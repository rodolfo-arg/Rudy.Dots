-- This file contains the configuration for setting up the lazy.nvim plugin manager in Neovim.

-- Autoread files when they change
vim.opt.autoread = true

-- Define the path to the lazy.nvim plugin
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Check if the lazy.nvim plugin is not already installed
if not vim.loop.fs_stat(lazypath) then
    -- Bootstrap lazy.nvim by cloning the repository
    -- stylua: ignore
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
        lazypath })
end

-- Prepend the lazy.nvim path to the runtime path
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

-- Use a lockfile outside of the repo/config dir to avoid permission issues
local lockdir = vim.fn.stdpath("state") .. "/lazy"
pcall(vim.fn.mkdir, lockdir, "p")

-- Setup lazy.nvim with the specified configuration
require("lazy").setup({
  lockfile = lockdir .. "/lazy-lock.json",
  spec = {
    -- Add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Import any extra modules here
    -- Editor plugins
    -- Removed harpoon2 to reduce clutter
    { import = "lazyvim.plugins.extras.editor.mini-files" },
    -- { import = "lazyvim.plugins.extras.editor.snacks_explorer" },
    { import = "lazyvim.plugins.extras.editor.snacks_picker" },

    -- Formatting plugins
    { import = "lazyvim.plugins.extras.formatting.biome" },
    { import = "lazyvim.plugins.extras.formatting.prettier" },

    -- Linting plugins
    { import = "lazyvim.plugins.extras.linting.eslint" },

    -- Language support plugins
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.lang.go" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.yaml" },

    -- Import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot of the plugins that support versioning
    -- have outdated releases, which may break your Neovim install.
    -- Track latest commits (LazyVim default) to match its ecosystem
    version = false,
  },
  install = { colorscheme = { "tokyonight", "habamax" } }, -- Specify colorschemes to install
  -- Automatically check for plugin updates, but don't pop intrusive windows
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      -- Disable some runtime path plugins to improve performance
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
      },
    },
  },
})
