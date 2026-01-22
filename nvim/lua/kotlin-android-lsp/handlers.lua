-- kotlin-android-lsp: Custom LSP handlers
-- Handles jdt:// URI conversion for navigation

local M = {}

local uri_module = require("kotlin-android-lsp.uri")

---Process location results, converting jdt:// URIs to zipfile://
---@param result table|nil LSP location result
---@return table|nil Processed result
local function process_locations(result)
  if not result then
    return nil
  end

  -- Handle both single location and location array
  local locations = vim.islist(result) and result or { result }
  local processed = {}

  for _, loc in ipairs(locations) do
    local new_loc = vim.deepcopy(loc)

    -- Check if this is a jdt:// URI
    if loc.uri and uri_module.is_jdt(loc.uri) then
      local zipfile = uri_module.jdt_to_zipfile(loc.uri)
      if zipfile then
        -- Convert jdt:// to jar: URI (which will be converted to zipfile:// by our patch)
        new_loc.uri = uri_module.jdt_to_jar(loc.uri)
        vim.notify(
          string.format("Converted jdt:// to source jar: %s", vim.fn.fnamemodify(zipfile, ":t")),
          vim.log.levels.DEBUG
        )
      end
    elseif loc.targetUri and uri_module.is_jdt(loc.targetUri) then
      local zipfile = uri_module.jdt_to_zipfile(loc.targetUri)
      if zipfile then
        new_loc.targetUri = uri_module.jdt_to_jar(loc.targetUri)
      end
    end

    table.insert(processed, new_loc)
  end

  return vim.islist(result) and processed or processed[1]
end

---Wrap the default definition handler to process jdt:// URIs
---@param handler function The original handler
---@return function The wrapped handler
local function wrap_location_handler(handler)
  return function(err, result, ctx, config)
    local processed = process_locations(result)
    return handler(err, processed, ctx, config)
  end
end

---Setup custom LSP handlers for jdt:// URI conversion
function M.setup()
  if vim.g.__kotlin_android_lsp_handlers_setup then
    return
  end
  vim.g.__kotlin_android_lsp_handlers_setup = true

  -- Store original handlers
  local orig_definition = vim.lsp.handlers["textDocument/definition"]
  local orig_declaration = vim.lsp.handlers["textDocument/declaration"]
  local orig_typeDefinition = vim.lsp.handlers["textDocument/typeDefinition"]
  local orig_implementation = vim.lsp.handlers["textDocument/implementation"]
  local orig_references = vim.lsp.handlers["textDocument/references"]

  -- Wrap handlers to process jdt:// URIs
  vim.lsp.handlers["textDocument/definition"] = wrap_location_handler(orig_definition)
  vim.lsp.handlers["textDocument/declaration"] = wrap_location_handler(orig_declaration)
  vim.lsp.handlers["textDocument/typeDefinition"] = wrap_location_handler(orig_typeDefinition)
  vim.lsp.handlers["textDocument/implementation"] = wrap_location_handler(orig_implementation)
  vim.lsp.handlers["textDocument/references"] = wrap_location_handler(orig_references)
end

return M
