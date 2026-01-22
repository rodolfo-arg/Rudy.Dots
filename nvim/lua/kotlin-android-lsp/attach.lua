-- kotlin-android-lsp: LSP attachment for jar source buffers
-- Handles attaching kotlin_lsp to zipfile:// buffers
-- jdtls is managed by nvim-jdtls via ftplugin/java.lua

local M = {}

local uri = require("kotlin-android-lsp.uri")

---Attach an LSP client to a zipfile buffer with proper didOpen notification
---@param bufnr number Buffer number
---@param client table LSP client
---@param lang_id string Language ID ("kotlin" or "java")
local function attach_with_didopen(bufnr, client, lang_id)
  if vim.lsp.buf_is_attached(bufnr, client.id) then
    return
  end

  -- Attach client to buffer
  vim.lsp.buf_attach_client(bufnr, client.id)

  -- Send explicit didOpen notification with correct jar: URI
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    local buf_uri = vim.uri_from_bufnr(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local text = table.concat(lines, "\n")

    client:notify("textDocument/didOpen", {
      textDocument = {
        uri = buf_uri,
        languageId = lang_id,
        version = 0,
        text = text,
      },
    })
  end)
end

---Attach kotlin_lsp to a zipfile buffer
---@param bufnr number Buffer number
local function attach_kotlin_lsp(bufnr)
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  for _, client in ipairs(clients) do
    attach_with_didopen(bufnr, client, "kotlin")
  end
end

---Attach jdtls to a zipfile buffer (if already running via nvim-jdtls)
---@param bufnr number Buffer number
local function attach_jdtls(bufnr)
  -- jdtls is started by nvim-jdtls via ftplugin/java.lua
  -- We just attach if it's already running
  local clients = vim.lsp.get_clients({ name = "jdtls" })
  for _, client in ipairs(clients) do
    attach_with_didopen(bufnr, client, "java")
  end
end

---Handle attachment for a buffer based on filetype
---@param bufnr number Buffer number
---@param filetype string File type
local function handle_attachment(bufnr, filetype)
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if not uri.is_zipfile(bufname) then
    return
  end

  if filetype == "kotlin" then
    attach_kotlin_lsp(bufnr)
  elseif filetype == "java" then
    -- Don't attach kotlin_lsp to Java buffers - it causes "not attached" errors
    -- jdtls is started by nvim-jdtls via ftplugin/java.lua
    -- Defer attachment to let nvim-jdtls start it first
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        attach_jdtls(bufnr)
      end
    end, 1000) -- Wait longer for jdtls to initialize
  end
end

---Setup autocmds for LSP attachment to zipfile buffers
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

  -- Handle BufReadPost for zipfile buffers (filetype may be set later)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    pattern = "zipfile://*",
    callback = function(args)
      -- Defer to let filetype detection and nvim-jdtls startup happen first
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          local ft = vim.bo[args.buf].filetype
          if ft == "kotlin" or ft == "java" then
            handle_attachment(args.buf, ft)
          end
        end
      end, 200)
    end,
  })
end

return M
