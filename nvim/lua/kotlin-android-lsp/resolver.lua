-- kotlin-android-lsp: Symbol resolver using treesitter
-- Resolves symbol under cursor to fully qualified name

local M = {}

---Get the word under cursor
---@return string|nil
local function get_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  if word and word ~= "" then
    return word
  end
  return nil
end

---Parse imports from a Java buffer using treesitter
---@param bufnr number
---@return table<string, string> Map of simple name to FQN
local function parse_java_imports(bufnr)
  local imports = {}

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "java")
  if not ok or not parser then
    return imports
  end

  local tree = parser:parse()[1]
  if not tree then
    return imports
  end

  local root = tree:root()

  -- Query for import declarations
  local query_str = "(import_declaration) @import"
  local ok_query, query = pcall(vim.treesitter.query.parse, "java", query_str)
  if not ok_query or not query then
    return imports
  end

  for _, node in query:iter_captures(root, bufnr) do
    local import_text = vim.treesitter.get_node_text(node, bufnr)
    -- Parse: "import com.example.ClassName;" or "import static ..."
    local fqn = import_text:match("import%s+static%s+([%w%.]+)") or import_text:match("import%s+([%w%.]+)")
    if fqn then
      -- Handle wildcard imports
      if fqn:match("%*$") then
        -- Store package prefix for wildcard
        local package = fqn:gsub("%.%*$", "")
        imports["*" .. package] = package
      else
        -- Get simple name from FQN
        local simple_name = fqn:match("([^%.]+)$")
        if simple_name then
          imports[simple_name] = fqn
        end
      end
    end
  end

  return imports
end

---Parse imports from a Kotlin buffer using treesitter
---@param bufnr number
---@return table<string, string> Map of simple name to FQN
local function parse_kotlin_imports(bufnr)
  local imports = {}

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "kotlin")
  if not ok or not parser then
    return imports
  end

  local tree = parser:parse()[1]
  if not tree then
    return imports
  end

  local root = tree:root()

  -- Query for import headers
  local query_str = "(import_header) @import"
  local ok_query, query = pcall(vim.treesitter.query.parse, "kotlin", query_str)
  if not ok_query or not query then
    return imports
  end

  for _, node in query:iter_captures(root, bufnr) do
    local import_text = vim.treesitter.get_node_text(node, bufnr)
    -- Parse: "import com.example.ClassName" or "import com.example.*"
    local fqn = import_text:match("import%s+([%w%.]+)")
    if fqn then
      if fqn:match("%*$") then
        local package = fqn:gsub("%.%*$", "")
        imports["*" .. package] = package
      else
        local simple_name = fqn:match("([^%.]+)$")
        if simple_name then
          imports[simple_name] = fqn
        end
      end
    end
  end

  return imports
end

---Parse package declaration from buffer
---@param bufnr number
---@param filetype string
---@return string|nil
local function get_package(bufnr, filetype)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 20, false)
  for _, line in ipairs(lines) do
    local package = line:match("^%s*package%s+([%w%.]+)")
    if package then
      return package
    end
  end
  return nil
end

---Check if a name looks like a type (starts with uppercase)
---@param name string
---@return boolean
local function is_type_name(name)
  return name:match("^[A-Z]") ~= nil
end

---Get the treesitter node under cursor and determine if it's a type reference
---@param bufnr number
---@return string|nil node_text, string|nil node_type
local function get_node_under_cursor(bufnr)
  local node = vim.treesitter.get_node()
  if not node then
    return get_word_under_cursor(), nil
  end

  local node_type = node:type()
  local node_text = vim.treesitter.get_node_text(node, bufnr)

  -- For identifier nodes, check parent to understand context
  if node_type == "identifier" or node_type == "simple_identifier" or node_type == "type_identifier" then
    local parent = node:parent()
    if parent then
      local parent_type = parent:type()
      -- Check if this is a type context
      if parent_type:match("type") or parent_type == "scoped_identifier" or parent_type == "user_type" then
        return node_text, "type"
      end
    end
    -- If it looks like a type name, treat it as such
    if is_type_name(node_text) then
      return node_text, "type"
    end
  end

  return node_text, node_type
end

---Resolve a symbol to its fully qualified name
---@param bufnr number Buffer number
---@return string|nil fqn, string|nil error_message
function M.resolve(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  -- Get symbol under cursor
  local symbol, node_type = get_node_under_cursor(bufnr)
  if not symbol or symbol == "" then
    return nil, "No symbol under cursor"
  end

  -- If it's already a FQN (contains dots), return as-is
  if symbol:match("%.") then
    return symbol, nil
  end

  -- Parse imports based on filetype
  local imports
  if filetype == "java" then
    imports = parse_java_imports(bufnr)
  elseif filetype == "kotlin" then
    imports = parse_kotlin_imports(bufnr)
  else
    return nil, "Unsupported filetype: " .. filetype
  end

  -- Check direct imports first
  if imports[symbol] then
    return imports[symbol], nil
  end

  -- Check wildcard imports
  local current_package = get_package(bufnr, filetype)
  local packages_to_check = {}

  -- Add current package first
  if current_package then
    table.insert(packages_to_check, current_package)
  end

  -- Add wildcard import packages
  for key, package in pairs(imports) do
    if key:match("^%*") then
      table.insert(packages_to_check, package)
    end
  end

  -- Add common Java packages that are implicitly imported
  if filetype == "java" then
    table.insert(packages_to_check, "java.lang")
  end

  -- Return potential FQNs to try
  -- The navigator will try each one against the index
  local potential_fqns = {}
  for _, package in ipairs(packages_to_check) do
    table.insert(potential_fqns, package .. "." .. symbol)
  end

  -- Also return the symbol itself as a potential FQN
  table.insert(potential_fqns, symbol)

  if #potential_fqns > 0 then
    return potential_fqns, nil
  end

  return nil, "Could not resolve symbol: " .. symbol
end

---Get imports for debugging
---@param bufnr number
---@return table
function M.get_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filetype = vim.bo[bufnr].filetype

  if filetype == "java" then
    return parse_java_imports(bufnr)
  elseif filetype == "kotlin" then
    return parse_kotlin_imports(bufnr)
  end

  return {}
end

return M
