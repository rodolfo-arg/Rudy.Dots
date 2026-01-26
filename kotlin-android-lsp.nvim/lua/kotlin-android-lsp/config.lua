-- kotlin-android-lsp: Configuration module

local M = {}

---@class KotlinAndroidLspConfig
---@field default_module string Default Gradle module name
---@field workspace_script string|nil Path to workspace generator script (nil = use builtin)
---@field cache_dir string Cache directory for generated files
---@field keymaps table Keymap configuration
---@field kotlin_lsp table Kotlin LSP specific settings
---@field jdtls table jdtls specific settings

---@type KotlinAndroidLspConfig
M.defaults = {
  default_module = "app",
  workspace_script = nil, -- Use builtin Lua generator
  cache_dir = vim.fn.stdpath("cache") .. "/kotlin-android-lsp",
  keymaps = {
    enabled = true,
    generate_workspace = "<leader>dk", -- Debug: generate Kotlin workspace
    workspace_info = "<leader>di", -- Debug: workspace info
  },
  kotlin_lsp = {
    enabled = true,
    cmd = nil, -- Auto-detect
    system_path = vim.fn.stdpath("cache") .. "/kotlin_lsp",
  },
  jdtls = {
    enabled = true,
    cmd = nil, -- Auto-detect
  },
  -- Android SDK settings
  android = {
    sdk_root = vim.env.ANDROID_SDK_ROOT or vim.env.ANDROID_HOME,
    prefer_sources_api = true, -- Prefer API level with available sources
  },
}

---@type KotlinAndroidLspConfig
M.options = {}

---Setup configuration with user options
---@param opts table|nil User options to merge with defaults
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})

  -- Ensure cache directory exists
  vim.fn.mkdir(M.options.cache_dir, "p")
end

return M
