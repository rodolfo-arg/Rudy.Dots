-- ftplugin/java.lua
-- nvim-jdtls configuration for Java files
-- Handles both regular Java files and zipfile:// buffers from jar sources

local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
  vim.notify("nvim-jdtls not loaded", vim.log.levels.WARN)
  return
end

-- Get buffer name to check for zipfile:// buffers
local bufname = vim.api.nvim_buf_get_name(0)
local is_zipfile = bufname:match("^zipfile://")

-- Find jdtls binary
local jdtls_bin = vim.fn.exepath("jdtls")
if jdtls_bin == "" then
  local home = vim.env.HOME or vim.fn.expand("~")
  jdtls_bin = home .. "/.nix-profile/bin/jdtls"
  if vim.fn.executable(jdtls_bin) ~= 1 then
    vim.notify("jdtls not found", vim.log.levels.WARN)
    return
  end
end

-- Determine root directory
local root_dir
if is_zipfile then
  -- For zipfile:// buffers, try to get root from kotlin_lsp
  local kotlin_clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  if #kotlin_clients > 0 and kotlin_clients[1].config.root_dir then
    root_dir = kotlin_clients[1].config.root_dir
  else
    root_dir = vim.fn.getcwd()
  end
else
  -- Normal root detection for regular files
  root_dir = vim.fs.root(0, {
    "gradlew", "mvnw", "settings.gradle", "settings.gradle.kts",
    "build.gradle", "build.gradle.kts", "pom.xml", ".git",
  }) or vim.fn.getcwd()
end

-- Create unique workspace directory for this project
local project_name = vim.fn.fnamemodify(root_dir, ":t")
local workspace_dir = vim.fn.stdpath("cache") .. "/jdtls-workspace/" .. project_name

-- Minimal jdtls configuration (gradle dependencies loaded async later)
local config = {
  name = "jdtls",
  cmd = { jdtls_bin },
  root_dir = root_dir,
  single_file_support = true,

  settings = {
    java = {
      eclipse = { downloadSources = true },
      maven = { downloadSources = true },
      inlayHints = { parameterNames = { enabled = "all" } },
      contentProvider = { preferred = "fernflower" },
      import = {
        gradle = { enabled = true, wrapper = { enabled = true } },
        maven = { enabled = true },
      },
      configuration = { updateBuildConfiguration = "automatic" },
    },
  },

  init_options = {
    extendedClientCapabilities = {
      classFileContentsSupport = true,
    },
    bundles = {},
  },

  capabilities = vim.lsp.protocol.make_client_capabilities(),

  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set("n", "<leader>jo", jdtls.organize_imports, vim.tbl_extend("force", opts, { desc = "Organize Imports" }))
    vim.keymap.set("n", "<leader>jv", jdtls.extract_variable, vim.tbl_extend("force", opts, { desc = "Extract Variable" }))
    vim.keymap.set("v", "<leader>jv", function() jdtls.extract_variable(true) end, vim.tbl_extend("force", opts, { desc = "Extract Variable" }))
    vim.keymap.set("n", "<leader>jc", jdtls.extract_constant, vim.tbl_extend("force", opts, { desc = "Extract Constant" }))
    vim.keymap.set("v", "<leader>jc", function() jdtls.extract_constant(true) end, vim.tbl_extend("force", opts, { desc = "Extract Constant" }))
    vim.keymap.set("v", "<leader>jm", function() jdtls.extract_method(true) end, vim.tbl_extend("force", opts, { desc = "Extract Method" }))
  end,
}

-- Start or attach jdtls
jdtls.start_or_attach(config)
