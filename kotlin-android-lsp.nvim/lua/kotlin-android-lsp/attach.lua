-- kotlin-android-lsp: Buffer attachment handler
-- Manages LSP attachment and custom navigation for different buffer types

local M = {}

local uri = require("kotlin-android-lsp.uri")
local navigator = require("kotlin-android-lsp.navigator")
local indexer = require("kotlin-android-lsp.indexer")

---Detach all LSP clients from a buffer
---@param bufnr number
local function detach_all_lsp(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  for _, client in ipairs(clients) do
    vim.lsp.buf_detach_client(bufnr, client.id)
  end
end

---Prevent LSP from attaching to a buffer and disable diagnostics
---@param bufnr number
local function prevent_lsp_attach(bufnr)
  -- Set a flag to prevent LSP attachment
  vim.b[bufnr].kotlin_android_lsp_no_lsp = true

  -- Disable diagnostics for this buffer (no LSP errors in dependency sources)
  vim.diagnostic.enable(false, { bufnr = bufnr })

  -- Detach any clients that may have already attached
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      detach_all_lsp(bufnr)
      -- Ensure diagnostics stay disabled after LSP detach
      vim.diagnostic.enable(false, { bufnr = bufnr })
    end
  end)
end

-- Flag to track if project has been initialized
local project_initialized = false

---Handle a zipfile:// buffer - disable LSP, enable custom navigation
---@param bufnr number
---@param filetype string
local function handle_zipfile_buffer(bufnr, filetype)
  -- Only handle Java and Kotlin files
  if filetype ~= "java" and filetype ~= "kotlin" then
    return
  end

  -- Prevent LSP from attaching and disable diagnostics
  prevent_lsp_attach(bufnr)

  -- Index the current jar immediately (fast, uses disk cache)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  indexer.index_from_zipfile(bufname)

  -- Setup custom navigator if not already done
  if not navigator.is_setup(bufnr) then
    navigator.setup_buffer(bufnr)
  end

  -- Trigger common sources indexing if not already done/in-progress
  -- This runs async and navigator will work once complete
  if indexer.get_status() == "not_started" then
    indexer.index_common_sources_async()
  end
end

---Check if current directory is a gradle/android project
---@return boolean
local function is_gradle_project()
  local markers = { "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts" }
  for _, marker in ipairs(markers) do
    if vim.fn.filereadable(vim.fn.getcwd() .. "/" .. marker) == 1 then
      return true
    end
  end
  return false
end

---Check if build is needed (no R.jar exists)
---@param cwd string
---@return boolean
local function needs_build(cwd)
  local config = require("kotlin-android-lsp.config")
  local module = config.options.default_module or "app"
  local module_dir = cwd .. "/" .. module:gsub(":", "/")

  -- Check for R.jar (indicates successful build)
  local r_jar_paths = {
    module_dir .. "/build/intermediates/compile_and_runtime_not_namespaced_r_class_jar/debug/processDebugResources/R.jar",
    module_dir .. "/build/intermediates/compile_and_runtime_not_namespaced_r_class_jar/debug/R.jar",
  }

  for _, path in ipairs(r_jar_paths) do
    if vim.fn.filereadable(path) == 1 then
      return false
    end
  end

  return true
end

---Show build errors in a floating window
---@param errors table List of error lines
local function show_build_errors(errors)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = { "Build Failed", string.rep("─", 50), "" }
  vim.list_extend(lines, errors)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(#lines + 2, 20)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " Gradle Build Errors ",
    title_pos = "center",
  })

  -- Close with q or Esc
  vim.keymap.set("n", "q", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
end

---Run assembleDebug and then generate workspace
---@param cwd string
---@param on_complete function|nil
local function run_build_and_setup(cwd, on_complete)
  local gradlew = cwd .. "/gradlew"
  if vim.fn.filereadable(gradlew) ~= 1 then
    vim.notify("gradlew not found", vim.log.levels.WARN)
    if on_complete then on_complete(false) end
    return
  end

  vim.notify("Building project (assembleDebug)...", vim.log.levels.INFO)

  local errors = {}
  local job_id = vim.fn.jobstart({ gradlew, "assembleDebug", "--console=plain" }, {
    cwd = cwd,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          -- Capture error lines
          if line:match("^e:") or line:match("error:") or line:match("FAILURE") then
            table.insert(errors, line)
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line:match("^e:") or line:match("error:") or line:match("Exception") then
            table.insert(errors, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        if exit_code == 0 then
          vim.notify("Build successful! Generating workspace...", vim.log.levels.INFO)

          -- Generate workspace.json
          local workspace = require("kotlin-android-lsp.workspace")
          local config = require("kotlin-android-lsp.config")
          workspace.generate(cwd, config.options.default_module)

          -- Wait a bit for workspace generation, then restart LSP
          vim.defer_fn(function()
            -- Restart kotlin_lsp to pick up new workspace
            local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
            for _, client in ipairs(clients) do
              vim.lsp.stop_client(client.id)
            end

            vim.defer_fn(function()
              vim.cmd("LspStart kotlin_lsp")
              vim.notify("Kotlin Android LSP: Ready!", vim.log.levels.INFO)

              -- Index sources for custom navigation
              if indexer.get_status() == "not_started" then
                indexer.index_common_sources_async()
              end

              if on_complete then on_complete(true) end
            end, 500)
          end, 1000)
        else
          -- Show build errors
          if #errors > 0 then
            show_build_errors(errors)
          else
            vim.notify("Build failed (exit code: " .. exit_code .. ")", vim.log.levels.ERROR)
          end
          if on_complete then on_complete(false) end
        end
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start gradle", vim.log.levels.ERROR)
    if on_complete then on_complete(false) end
  end
end

---Initialize project: build if needed, generate workspace, index sources
---@param force boolean|nil Force re-initialization
local function initialize_project(force)
  if project_initialized and not force then
    return
  end
  project_initialized = true

  -- Only initialize for gradle projects
  if not is_gradle_project() then
    return
  end

  local cwd = vim.fn.getcwd()

  -- Check if we need to build
  if needs_build(cwd) then
    vim.notify("Kotlin Android LSP: Project needs build...", vim.log.levels.INFO)
    run_build_and_setup(cwd)
  else
    -- Build exists, just generate workspace if needed and index
    local workspace_file = cwd .. "/workspace.json"
    if vim.fn.filereadable(workspace_file) ~= 1 then
      vim.notify("Generating workspace.json...", vim.log.levels.INFO)
      local workspace = require("kotlin-android-lsp.workspace")
      local config = require("kotlin-android-lsp.config")
      workspace.generate(cwd, config.options.default_module)
    end

    -- Index sources
    if force or indexer.get_status() == "not_started" then
      vim.defer_fn(function()
        indexer.index_common_sources_async(function()
          vim.notify("Kotlin Android LSP: Ready!", vim.log.levels.INFO)
        end)
      end, 100)
    end
  end
end

---Refresh project: rebuild and regenerate workspace
function M.refresh()
  local cwd = vim.fn.getcwd()
  if not is_gradle_project() then
    vim.notify("Not a Gradle project", vim.log.levels.WARN)
    return
  end

  run_build_and_setup(cwd, function(success)
    if success then
      indexer.refresh()
    end
  end)
end

---Handle attachment for a buffer based on filetype
---@param bufnr number Buffer number
---@param filetype string File type
local function handle_attachment(bufnr, filetype)
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- For zipfile:// buffers, use custom navigation instead of LSP
  if uri.is_zipfile(bufname) then
    handle_zipfile_buffer(bufnr, filetype)
    return
  end

  -- For Kotlin files in gradle projects, initialize project on first open
  if filetype == "kotlin" and not project_initialized then
    initialize_project()
  end

  -- For regular project files, let LSP handle normally
  -- (kotlin_lsp for .kt files, jdtls for .java files via ftplugin)
end

---Setup autocmds for buffer handling
function M.setup()
  if vim.g.__kotlin_android_lsp_attach_setup then
    return
  end
  vim.g.__kotlin_android_lsp_attach_setup = true

  local group = vim.api.nvim_create_augroup("KotlinAndroidLspAttach", { clear = true })

  -- Handle FileType events for kotlin and java
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "kotlin", "java" },
    callback = function(args)
      handle_attachment(args.buf, args.match)
    end,
  })

  -- Handle BufReadPost for zipfile buffers
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    pattern = "zipfile://*",
    callback = function(args)
      -- Defer to let filetype detection happen first
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          local ft = vim.bo[args.buf].filetype
          handle_attachment(args.buf, ft)
        end
      end, 50)
    end,
  })

  -- Intercept LspAttach to prevent attachment to zipfile buffers
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local bufnr = args.buf
      local bufname = vim.api.nvim_buf_get_name(bufnr)

      -- If this is a zipfile buffer, detach the client
      if uri.is_zipfile(bufname) or vim.b[bufnr].kotlin_android_lsp_no_lsp then
        local client_id = args.data.client_id
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            pcall(vim.lsp.buf_detach_client, bufnr, client_id)
          end
        end)
      end
    end,
  })
end

return M
