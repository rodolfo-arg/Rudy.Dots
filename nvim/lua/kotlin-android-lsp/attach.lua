-- kotlin-android-lsp: LSP attachment for jar source buffers
-- Handles attaching kotlin_lsp and jdtls to zipfile:// buffers

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

---Get the project root from kotlin_lsp or fallback to cwd
---@return string
local function get_project_root()
  local kotlin_clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  if #kotlin_clients > 0 and kotlin_clients[1].config.root_dir then
    return kotlin_clients[1].config.root_dir
  end
  return vim.fn.getcwd()
end

---Start jdtls for a zipfile buffer
---@param bufnr number Buffer number
local function start_jdtls_for_zipfile(bufnr)
  local jdtls_bin = vim.fn.exepath("jdtls")
  if jdtls_bin == "" then
    -- Try nix-profile fallback
    local home = vim.env.HOME or vim.fn.expand("~")
    jdtls_bin = home .. "/.nix-profile/bin/jdtls"
    if vim.fn.executable(jdtls_bin) ~= 1 then
      return nil
    end
  end

  local root_dir = get_project_root()

  -- Start jdtls with vim.lsp.start
  local client_id = vim.lsp.start({
    name = "jdtls",
    cmd = { jdtls_bin },
    root_dir = root_dir,
    filetypes = { "java" },
    single_file_support = true,
    settings = {
      java = {
        project = {
          referencedLibraries = {},
        },
        inlayHints = {
          parameterNames = { enabled = "all" },
        },
      },
    },
    init_options = {
      extendedClientCapabilities = {
        classFileContentsSupport = true,
      },
    },
  }, {
    bufnr = bufnr,
    reuse_client = function(client, config)
      return client.name == "jdtls"
    end,
  })

  return client_id
end

---Attach jdtls to a zipfile buffer
---@param bufnr number Buffer number
local function attach_jdtls(bufnr)
  local clients = vim.lsp.get_clients({ name = "jdtls" })
  if #clients > 0 then
    -- jdtls already running, attach it
    for _, client in ipairs(clients) do
      attach_with_didopen(bufnr, client, "java")
    end
  else
    -- Start jdtls for this buffer
    local client_id = start_jdtls_for_zipfile(bufnr)
    if client_id then
      vim.schedule(function()
        local client = vim.lsp.get_client_by_id(client_id)
        if client then
          attach_with_didopen(bufnr, client, "java")
        end
      end)
    end
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
    -- Try both kotlin_lsp (for cross-language) and jdtls (for Java-specific)
    attach_kotlin_lsp(bufnr)
    attach_jdtls(bufnr)
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
      -- Defer to let filetype detection happen first
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          local ft = vim.bo[args.buf].filetype
          if ft == "kotlin" or ft == "java" then
            handle_attachment(args.buf, ft)
          end
        end
      end, 100)
    end,
  })
end

return M
