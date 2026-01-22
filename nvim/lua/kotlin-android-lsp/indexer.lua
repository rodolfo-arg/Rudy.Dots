-- kotlin-android-lsp: Lazy jar source indexer
-- Indexes source jars on-demand to map FQN -> zipfile path

local M = {}

-- In-memory index cache: { jar_path = { "com.example.ClassName" = "path/to/Class.java" } }
local jar_indexes = {}

-- Global FQN index: { "com.example.ClassName" = "zipfile://path.jar::path/to/Class.java" }
local fqn_index = {}

-- Cache directory
local cache_dir = vim.fn.stdpath("cache") .. "/kotlin-android-lsp/indexes"

---Ensure cache directory exists
local function ensure_cache_dir()
  if vim.fn.isdirectory(cache_dir) ~= 1 then
    vim.fn.mkdir(cache_dir, "p")
  end
end

---Get cache file path for a jar
---@param jar_path string
---@return string
local function get_cache_path(jar_path)
  local hash = vim.fn.sha256(jar_path):sub(1, 16)
  local name = vim.fn.fnamemodify(jar_path, ":t:r")
  return cache_dir .. "/" .. name .. "-" .. hash .. ".json"
end

---Load cached index for a jar
---@param jar_path string
---@return table|nil
local function load_cached_index(jar_path)
  local cache_path = get_cache_path(jar_path)
  if vim.fn.filereadable(cache_path) ~= 1 then
    return nil
  end

  local f = io.open(cache_path, "r")
  if not f then return nil end

  local content = f:read("*all")
  f:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then return nil end

  -- Check if jar is newer than cache
  local jar_mtime = vim.fn.getftime(jar_path)
  if data.mtime and data.mtime >= jar_mtime then
    return data.index
  end

  return nil
end

---Save index to cache
---@param jar_path string
---@param index table
local function save_cached_index(jar_path, index)
  ensure_cache_dir()
  local cache_path = get_cache_path(jar_path)

  local data = {
    jar_path = jar_path,
    mtime = vim.fn.getftime(jar_path),
    index = index,
  }

  local f = io.open(cache_path, "w")
  if f then
    f:write(vim.json.encode(data))
    f:close()
  end
end

---Extract package name from file path
---@param file_path string e.g., "androidx/test/InstrumentationRegistry.java"
---@return string, string package_name, class_name
local function path_to_package(file_path)
  -- Remove .java or .kt extension
  local base = file_path:gsub("%.[jk][at][v]?a?$", "")

  -- Handle nested classes (e.g., Outer$Inner)
  base = base:gsub("%$.*$", "")

  -- Convert path separators to dots
  local parts = vim.split(base, "/")
  local class_name = parts[#parts]

  -- Build package name from all but last part
  local package_parts = {}
  for i = 1, #parts - 1 do
    table.insert(package_parts, parts[i])
  end

  local package_name = table.concat(package_parts, ".")
  return package_name, class_name
end

---Index a source jar file
---@param jar_path string Full path to the source jar
---@return table Index mapping FQN to inner path
function M.index_jar(jar_path)
  -- Check memory cache first
  if jar_indexes[jar_path] then
    return jar_indexes[jar_path]
  end

  -- Check disk cache
  local cached = load_cached_index(jar_path)
  if cached then
    jar_indexes[jar_path] = cached
    -- Merge into global FQN index
    for fqn, inner_path in pairs(cached) do
      fqn_index[fqn] = "zipfile://" .. jar_path .. "::" .. inner_path
    end
    return cached
  end

  -- Index the jar by listing contents
  local index = {}
  local handle = io.popen('unzip -l "' .. jar_path .. '" 2>/dev/null')
  if not handle then
    return index
  end

  for line in handle:lines() do
    -- Parse unzip -l output: "  1234  01-01-2010 00:00   path/to/File.java"
    local file_path = line:match("%s+%d+%s+[%d-]+%s+[%d:]+%s+(.+)$")
    if file_path and (file_path:match("%.java$") or file_path:match("%.kt$")) then
      -- Skip test files and internal files
      if not file_path:match("/test/") and not file_path:match("/internal/") then
        local package_name, class_name = path_to_package(file_path)
        if class_name and class_name ~= "" then
          local fqn
          if package_name and package_name ~= "" then
            fqn = package_name .. "." .. class_name
          else
            fqn = class_name
          end
          index[fqn] = file_path
        end
      end
    end
  end
  handle:close()

  -- Cache to memory and disk
  jar_indexes[jar_path] = index
  save_cached_index(jar_path, index)

  -- Merge into global FQN index
  for fqn, inner_path in pairs(index) do
    fqn_index[fqn] = "zipfile://" .. jar_path .. "::" .. inner_path
  end

  return index
end

---Find source jar for a class jar in gradle cache
---@param class_jar_path string Path to class jar
---@return string|nil Path to source jar
function M.find_source_jar(class_jar_path)
  -- Convert class jar to source jar name
  local source_jar = class_jar_path:gsub("%.jar$", "-sources.jar")
  if vim.fn.filereadable(source_jar) == 1 then
    return source_jar
  end

  -- Try finding in same directory structure
  local dir = vim.fn.fnamemodify(class_jar_path, ":h")
  local name = vim.fn.fnamemodify(class_jar_path, ":t:r")
  local source_name = name .. "-sources.jar"

  -- Check sibling directories (gradle cache structure)
  local parent = vim.fn.fnamemodify(dir, ":h")
  local handle = io.popen('find "' .. parent .. '" -name "' .. source_name .. '" 2>/dev/null | head -1')
  if handle then
    local result = handle:read("*l")
    handle:close()
    if result and result ~= "" then
      return result
    end
  end

  return nil
end

---Look up a fully qualified name in the index
---@param fqn string Fully qualified name (e.g., "android.app.Activity")
---@return string|nil zipfile path if found
function M.lookup(fqn)
  return fqn_index[fqn]
end

---Index all source jars that might contain a package
---@param package_prefix string Package prefix to search for
function M.index_package(package_prefix)
  -- Convert package to path pattern
  local path_pattern = package_prefix:gsub("%.", "/")

  -- Search gradle cache for matching source jars
  local gradle_cache = (vim.env.HOME or "") .. "/.gradle/caches/modules-2/files-2.1"
  if vim.fn.isdirectory(gradle_cache) ~= 1 then
    return
  end

  -- Find source jars (limit to avoid overwhelming)
  local handle = io.popen('find "' .. gradle_cache .. '" -name "*-sources.jar" 2>/dev/null | head -100')
  if not handle then return end

  local jars_to_index = {}
  for jar_path in handle:lines() do
    -- Quick check if jar might contain the package
    local check = io.popen('unzip -l "' .. jar_path .. '" 2>/dev/null | grep -q "' .. path_pattern .. '" && echo yes')
    if check then
      local result = check:read("*l")
      check:close()
      if result == "yes" then
        table.insert(jars_to_index, jar_path)
      end
    end
  end
  handle:close()

  -- Index matching jars
  for _, jar_path in ipairs(jars_to_index) do
    M.index_jar(jar_path)
  end
end

---Index jar containing a specific zipfile buffer
---@param zipfile_path string e.g., "zipfile:///path/to/file.jar::inner/path"
function M.index_from_zipfile(zipfile_path)
  local jar_path = zipfile_path:match("^zipfile://(.-)::") or zipfile_path:match("^zipfile://(.+)$")
  if jar_path then
    M.index_jar(jar_path)
  end
end

---Get all indexed FQNs (for debugging)
---@return table
function M.get_fqn_index()
  return fqn_index
end

---Clear all caches
function M.clear_cache()
  jar_indexes = {}
  fqn_index = {}
  -- Clear disk cache
  vim.fn.delete(cache_dir, "rf")
end

return M
