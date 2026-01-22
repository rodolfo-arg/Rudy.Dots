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

---Prevent LSP from attaching to a buffer
---@param bufnr number
local function prevent_lsp_attach(bufnr)
  -- Set a flag to prevent LSP attachment
  vim.b[bufnr].kotlin_android_lsp_no_lsp = true

  -- Detach any clients that may have already attached
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      detach_all_lsp(bufnr)
    end
  end)
end

-- Flag to track if common sources have been indexed
local common_sources_indexed = false
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

  -- Prevent LSP from attaching
  prevent_lsp_attach(bufnr)

  -- Index common sources (JDK, Android SDK) once
  if not common_sources_indexed then
    common_sources_indexed = true
    -- Run async to not block
    vim.schedule(function()
      indexer.index_common_sources()
    end)
  end

  -- Index the current jar
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  indexer.index_from_zipfile(bufname)

  -- Setup custom navigator if not already done
  if not navigator.is_setup(bufnr) then
    navigator.setup_buffer(bufnr)
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

---Initialize project: generate workspace and index sources
local function initialize_project()
  if project_initialized then
    return
  end
  project_initialized = true

  -- Only initialize for gradle projects
  if not is_gradle_project() then
    return
  end

  local cwd = vim.fn.getcwd()
  local workspace_file = cwd .. "/workspace.json"

  -- Show loading notification
  vim.notify("Kotlin Android LSP: Initializing project...", vim.log.levels.INFO)

  -- Generate workspace.json if it doesn't exist
  if vim.fn.filereadable(workspace_file) ~= 1 then
    vim.notify("Generating workspace.json...", vim.log.levels.INFO)
    local workspace = require("kotlin-android-lsp.workspace")
    local config = require("kotlin-android-lsp.config")
    workspace.generate(cwd, config.options.default_module)
  end

  -- Index sources in background
  vim.defer_fn(function()
    vim.notify("Indexing sources (JDK, Android SDK, Gradle)...", vim.log.levels.INFO)

    -- Index in chunks to not block UI
    vim.schedule(function()
      indexer.index_jdk()
      vim.schedule(function()
        indexer.index_android_sdk()
        vim.schedule(function()
          local count = indexer.index_gradle_sources()
          vim.notify(string.format("Indexing complete: %d source jars indexed", count), vim.log.levels.INFO)
        end)
      end)
    end)
  end, 100)
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
