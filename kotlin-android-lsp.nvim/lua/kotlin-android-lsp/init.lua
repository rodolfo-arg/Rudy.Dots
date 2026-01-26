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

  vim.api.nvim_create_user_command("KotlinIndexSources", function()
    M.indexer.index_common_sources_async()
  end, {
    desc = "Index JDK, Android SDK, and Gradle sources",
  })

  vim.api.nvim_create_user_command("KotlinRefresh", function()
    M.attach.refresh()
  end, {
    desc = "Refresh dependency index (re-index all sources)",
  })

  vim.api.nvim_create_user_command("KotlinStatus", function()
    local status = M.indexer.get_status()
    local fqn_count = 0
    for _ in pairs(M.indexer.get_fqn_index()) do
      fqn_count = fqn_count + 1
    end
    vim.notify(string.format("Kotlin Android LSP Status:\n- Indexing: %s\n- FQNs indexed: %d", status, fqn_count), vim.log.levels.INFO)
  end, {
    desc = "Show indexing status",
  })

  vim.api.nvim_create_user_command("KotlinLookup", function(cmd_opts)
    local fqn = cmd_opts.args
    if fqn == "" then
      fqn = vim.fn.expand("<cword>")
    end
    local result = M.indexer.lookup(fqn)
    if result then
      vim.notify("Found: " .. fqn .. "\n-> " .. result, vim.log.levels.INFO)
    else
      vim.notify("Not found: " .. fqn, vim.log.levels.WARN)
    end
  end, {
    nargs = "?",
    desc = "Lookup a fully qualified name in the index",
  })

  vim.api.nvim_create_user_command("KotlinAssembleDebug", function()
    M.assemble_debug()
  end, {
    desc = "Run ./gradlew assembleDebug",
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
    -- Assemble debug keymap
    vim.keymap.set("n", "<leader>da", function()
      M.assemble_debug()
    end, { desc = "Gradle assembleDebug" })
  end
end

---Run ./gradlew assembleDebug
function M.assemble_debug()
  local cwd = vim.fn.getcwd()
  local gradlew = cwd .. "/gradlew"

  if vim.fn.filereadable(gradlew) ~= 1 then
    vim.notify("gradlew not found in " .. cwd, vim.log.levels.ERROR)
    return
  end

  vim.notify("Running assembleDebug...", vim.log.levels.INFO)

  vim.fn.jobstart({ gradlew, "assembleDebug" }, {
    cwd = cwd,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" and (line:match("BUILD") or line:match("FAILURE") or line:match("error:")) then
            vim.schedule(function()
              vim.notify(line, vim.log.levels.INFO)
            end)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" and line:match("error") then
            vim.schedule(function()
              vim.notify(line, vim.log.levels.WARN)
            end)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          vim.notify("assembleDebug completed successfully!", vim.log.levels.INFO)
          -- Prompt to regenerate workspace
          vim.ui.select({ "Yes", "No" }, {
            prompt = "Regenerate workspace.json to pick up generated sources?",
          }, function(choice)
            if choice == "Yes" then
              M.workspace.generate(cwd, M.config.options.default_module)
            end
          end)
        else
          vim.notify("assembleDebug failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
        end
      end)
    end,
  })
end

return M
