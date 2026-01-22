-- kotlin-android-lsp: Kotlin/Android LSP support for Neovim
-- Provides workspace generation, URI mapping, and multi-layer navigation

local M = {}

M.config = require("kotlin-android-lsp.config")
M.uri = require("kotlin-android-lsp.uri")
M.workspace = require("kotlin-android-lsp.workspace")
M.attach = require("kotlin-android-lsp.attach")
M.handlers = require("kotlin-android-lsp.handlers")
M.indexer = require("kotlin-android-lsp.indexer")
M.resolver = require("kotlin-android-lsp.resolver")
M.navigator = require("kotlin-android-lsp.navigator")

---Setup the plugin with user options
---@param opts table|nil User configuration options
function M.setup(opts)
  M.config.setup(opts)
  M.uri.setup()
  M.attach.setup()
  M.handlers.setup()

  -- Register user commands
  vim.api.nvim_create_user_command("KotlinWorkspaceGenerate", function(cmd_opts)
    local project_root = cmd_opts.args ~= "" and cmd_opts.args or vim.fn.getcwd()
    local module = M.config.options.default_module
    M.workspace.generate(project_root, module)
  end, {
    nargs = "?",
    complete = "dir",
    desc = "Generate Kotlin LSP workspace.json for the given or current directory",
  })

  vim.api.nvim_create_user_command("KotlinWorkspaceInfo", function()
    M.workspace.info()
  end, {
    desc = "Show Kotlin LSP workspace information",
  })

  -- Debug commands for custom navigator
  vim.api.nvim_create_user_command("KotlinShowImports", function()
    local imports = M.resolver.get_imports()
    local lines = { "Imports:" }
    for simple, fqn in pairs(imports) do
      table.insert(lines, string.format("  %s -> %s", simple, fqn))
    end
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {
    desc = "Show parsed imports for current buffer",
  })

  vim.api.nvim_create_user_command("KotlinClearCache", function()
    M.indexer.clear_cache()
    vim.notify("Index cache cleared", vim.log.levels.INFO)
  end, {
    desc = "Clear the dependency index cache",
  })

  -- Register keymaps if enabled
  if M.config.options.keymaps.enabled then
    local km = M.config.options.keymaps
    if km.generate_workspace then
      vim.keymap.set("n", km.generate_workspace, function()
        M.workspace.generate(vim.fn.getcwd(), M.config.options.default_module)
      end, { desc = "Generate Kotlin workspace.json" })
    end
    if km.workspace_info then
      vim.keymap.set("n", km.workspace_info, function()
        M.workspace.info()
      end, { desc = "Show Kotlin workspace info" })
    end
  end
end

return M
