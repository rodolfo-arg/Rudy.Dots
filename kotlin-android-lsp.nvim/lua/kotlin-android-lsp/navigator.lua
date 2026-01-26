-- kotlin-android-lsp: Custom navigator for zipfile:// buffers
-- Provides go-to-definition without relying on LSP

local M = {}

local indexer = require("kotlin-android-lsp.indexer")
local resolver = require("kotlin-android-lsp.resolver")
local uri_module = require("kotlin-android-lsp.uri")

---Navigate to a file location (handles both zipfile:// and regular paths)
---@param target_path string
local function goto_location(target_path)
  -- Use vim.cmd.edit to open the file
  local ok, err = pcall(vim.cmd.edit, target_path)
  if not ok then
    vim.notify("Failed to open: " .. target_path .. "\n" .. tostring(err), vim.log.levels.ERROR)
  end
end

---Perform the actual definition lookup
---@param candidates table List of FQN candidates
---@return boolean success Whether navigation was successful
local function do_lookup(candidates)
  -- Try each candidate against the index
  for _, fqn in ipairs(candidates) do
    local target = indexer.lookup(fqn)
    if target then
      goto_location(target)
      return true
    end
  end

  -- If not found in index, try to index relevant packages
  local first_candidate = candidates[1]
  if first_candidate then
    local package_prefix = first_candidate:match("^([%w%.]+)%.[^%.]+$")
    if package_prefix then
      -- Index packages that might contain this class
      indexer.index_package(package_prefix)

      -- Try lookup again
      for _, fqn in ipairs(candidates) do
        local target = indexer.lookup(fqn)
        if target then
          goto_location(target)
          return true
        end
      end
    end
  end

  return false
end

---Custom go-to-definition handler for zipfile:// buffers
function M.goto_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  -- Index the current jar if not already indexed
  if uri_module.is_zipfile(bufname) then
    indexer.index_from_zipfile(bufname)
  end

  -- Resolve symbol under cursor
  local result, err = resolver.resolve(bufnr)
  if not result then
    vim.notify(err or "Could not resolve symbol", vim.log.levels.WARN)
    return
  end

  -- result can be a string (single FQN) or table (multiple candidates)
  local candidates = type(result) == "table" and result or { result }

  -- Check indexing status
  local status = indexer.get_status()

  if status == "in_progress" then
    -- Indexing is in progress, wait for it to complete then retry
    vim.notify("Waiting for index to complete...", vim.log.levels.INFO)
    indexer.on_ready(function()
      vim.schedule(function()
        if not do_lookup(candidates) then
          vim.notify("Definition not found for: " .. (candidates[1] or "unknown"), vim.log.levels.WARN)
        end
      end)
    end)
    return
  end

  if status == "not_started" then
    -- Trigger indexing and then lookup
    vim.notify("Starting index...", vim.log.levels.INFO)
    indexer.index_common_sources_async(function()
      vim.schedule(function()
        if not do_lookup(candidates) then
          vim.notify("Definition not found for: " .. (candidates[1] or "unknown"), vim.log.levels.WARN)
        end
      end)
    end)
    return
  end

  -- Indexing is complete, do lookup directly
  if not do_lookup(candidates) then
    vim.notify("Definition not found for: " .. (candidates[1] or "unknown"), vim.log.levels.WARN)
  end
end

---Custom references handler (basic - just search in current jar)
function M.goto_references()
  local bufnr = vim.api.nvim_get_current_buf()
  local word = vim.fn.expand("<cword>")

  if not word or word == "" then
    vim.notify("No symbol under cursor", vim.log.levels.WARN)
    return
  end

  -- Use grep to find references in the current buffer's jar
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  local jar_path = bufname:match("^zipfile://(.-)::") or bufname:match("^zipfile://(.+)$")

  if jar_path then
    -- Search for the word in the jar
    vim.notify("Searching for references to: " .. word, vim.log.levels.INFO)

    -- Use quickfix list to show results
    local results = {}
    local handle = io.popen('unzip -p "' .. jar_path .. '" "*.java" "*.kt" 2>/dev/null | grep -n "' .. word .. '" | head -50')
    if handle then
      for line in handle:lines() do
        table.insert(results, { text = line })
      end
      handle:close()
    end

    if #results > 0 then
      vim.fn.setqflist(results)
      vim.cmd("copen")
    else
      vim.notify("No references found for: " .. word, vim.log.levels.INFO)
    end
  end
end

---Setup buffer-local keymaps for a zipfile buffer
---@param bufnr number
function M.setup_buffer(bufnr)
  local opts = { buffer = bufnr, silent = true }

  -- Override gd for custom navigation
  vim.keymap.set("n", "gd", M.goto_definition, vim.tbl_extend("force", opts, { desc = "Goto Definition (custom)" }))

  -- Override gr for references (basic)
  vim.keymap.set("n", "gr", M.goto_references, vim.tbl_extend("force", opts, { desc = "Goto References (custom)" }))

  -- Add K for hover info (show FQN and imports)
  vim.keymap.set("n", "K", function()
    local result, err = resolver.resolve(bufnr)
    if result then
      local fqns = type(result) == "table" and result or { result }
      local msg = "Possible FQNs:\n" .. table.concat(fqns, "\n")

      -- Check which ones are in index
      for _, fqn in ipairs(fqns) do
        local target = indexer.lookup(fqn)
        if target then
          msg = msg .. "\n\nFound: " .. fqn .. "\n-> " .. target
          break
        end
      end

      vim.notify(msg, vim.log.levels.INFO)
    else
      vim.notify(err or "No info available", vim.log.levels.WARN)
    end
  end, vim.tbl_extend("force", opts, { desc = "Show symbol info" }))

  -- Notify that custom navigation is active
  vim.b[bufnr].kotlin_android_lsp_navigator = true
end

---Check if navigator is set up for a buffer
---@param bufnr number
---@return boolean
function M.is_setup(bufnr)
  return vim.b[bufnr].kotlin_android_lsp_navigator == true
end

return M
