-- kotlin-android-lsp: URI mapping utilities
-- Handles bidirectional conversion between jar: and zipfile:// URIs

local M = {}

local orig_uri_to_fname = nil
local orig_uri_from_fname = nil

---Convert zipfile:// path to jar: URI
---@param fname string The zipfile:// path
---@return string The jar: URI
local function zipfile_to_jar(fname)
  -- zipfile:///path/to/file.jar::inner/path/File.kt
  -- -> jar:file:///path/to/file.jar!/inner/path/File.kt
  local rest = fname:sub(11) -- Remove "zipfile://"
  local jar_part, inner = rest:match("^(.-)::(.+)$")
  jar_part = jar_part or rest

  if inner and inner ~= "" then
    inner = inner:gsub("^/+", "") -- Strip leading slashes
  end

  if jar_part == "" then
    return orig_uri_from_fname(fname)
  end

  local file_uri = orig_uri_from_fname(jar_part)
  if inner and inner ~= "" then
    return "jar:" .. file_uri .. "!/" .. inner
  end
  return "jar:" .. file_uri .. "!/"
end

---Convert jar: URI to zipfile:// path
---@param uri string The jar: URI
---@return string The zipfile:// path
local function jar_to_zipfile(uri)
  -- jar:file:///path/to/file.jar!/inner/path/File.kt
  -- -> zipfile:///path/to/file.jar::inner/path/File.kt
  local rest = uri:sub(5) -- Remove "jar:"
  local jar_part, inner = rest:match("^(.-)!/(.+)$")

  if not jar_part then
    jar_part = rest:match("^(.-)!$")
  end
  jar_part = jar_part or rest

  local jar_path
  if jar_part:match("^file:") then
    jar_path = orig_uri_to_fname(jar_part)
  else
    jar_path = vim.uri_decode(jar_part):gsub("^/*", "/")
  end

  if inner and inner ~= "" then
    inner = inner:gsub("^/+", "") -- Strip leading slashes
  end

  if jar_path ~= "" then
    local zip_uri = "zipfile://" .. jar_path
    if inner and inner ~= "" then
      zip_uri = zip_uri .. "::" .. inner
    else
      zip_uri = zip_uri .. "::"
    end
    return zip_uri
  end

  return orig_uri_to_fname(uri)
end

---Setup URI mapping by patching vim.uri_to_fname and vim.uri_from_fname
function M.setup()
  if vim.g.__kotlin_android_lsp_uri_patched then
    return
  end
  vim.g.__kotlin_android_lsp_uri_patched = true

  orig_uri_to_fname = vim.uri_to_fname
  orig_uri_from_fname = vim.uri_from_fname

  vim.uri_from_fname = function(fname)
    if type(fname) == "string" and fname:sub(1, 10) == "zipfile://" then
      return zipfile_to_jar(fname)
    end
    return orig_uri_from_fname(fname)
  end

  vim.uri_to_fname = function(uri)
    if type(uri) == "string" and uri:sub(1, 4) == "jar:" then
      return jar_to_zipfile(uri)
    end
    -- Handle jdt:// URIs by converting to zipfile:// if source jar available
    if type(uri) == "string" and uri:sub(1, 6) == "jdt://" then
      local zipfile = M.jdt_to_zipfile(uri)
      if zipfile then
        return zipfile
      end
      -- Fall through to let nvim-jdtls handle it via BufReadCmd
    end
    return orig_uri_to_fname(uri)
  end
end

---Check if a buffer name is a zipfile URI
---@param bufname string The buffer name
---@return boolean
function M.is_zipfile(bufname)
  return type(bufname) == "string" and bufname:sub(1, 10) == "zipfile://"
end

---Check if a URI is a jar URI
---@param uri string The URI
---@return boolean
function M.is_jar(uri)
  return type(uri) == "string" and uri:sub(1, 4) == "jar:"
end

---Check if a URI is a jdt URI
---@param uri string The URI
---@return boolean
function M.is_jdt(uri)
  return type(uri) == "string" and uri:sub(1, 6) == "jdt://"
end

---Find source jar for a class jar in gradle cache
---@param class_jar_name string The class jar filename (e.g., "monitor-1.6.1.jar")
---@return string|nil The full path to the source jar
local function find_source_jar(class_jar_name)
  -- Remove .jar extension and add -sources.jar
  local base_name = class_jar_name:gsub("%.jar$", "")
  local source_jar_name = base_name .. "-sources.jar"

  local gradle_cache = (vim.env.HOME or "") .. "/.gradle/caches/modules-2/files-2.1"
  if vim.fn.isdirectory(gradle_cache) ~= 1 then
    return nil
  end

  -- Search for the source jar in gradle cache
  local handle = io.popen('find "' .. gradle_cache .. '" -name "' .. source_jar_name .. '" 2>/dev/null | head -1')
  if handle then
    local result = handle:read("*l")
    handle:close()
    if result and result ~= "" then
      return result
    end
  end

  return nil
end

---Convert jdt:// URI to zipfile:// path if source jar available
---Format: jdt://contents/artifact.jar/com.example/ClassName.class?...
---@param uri string The jdt:// URI
---@return string|nil The zipfile:// path, or nil if no source found
function M.jdt_to_zipfile(uri)
  if not M.is_jdt(uri) then
    return nil
  end

  -- Parse jdt:// URI
  -- Example: jdt://contents/monitor-1.6.1.jar/androidx.test.platform.app/InstrumentationRegistry.class?...
  local jar_name, package_path, class_name = uri:match("jdt://contents/([^/]+)/([^?]+)/([^?%.]+)%.class")

  if not jar_name or not class_name then
    -- Try alternate format without package
    jar_name, class_name = uri:match("jdt://contents/([^/]+)/([^?%.]+)%.class")
    package_path = ""
  end

  if not jar_name then
    return nil
  end

  -- Find corresponding source jar
  local source_jar = find_source_jar(jar_name)
  if not source_jar then
    return nil
  end

  -- Build the inner path (convert package.name to package/name)
  local inner_path
  if package_path and package_path ~= "" then
    inner_path = package_path:gsub("%.", "/") .. "/" .. class_name .. ".java"
  else
    inner_path = class_name .. ".java"
  end

  -- Construct zipfile:// URI
  return "zipfile://" .. source_jar .. "::" .. inner_path
end

---Convert jdt:// URI to jar: URI (for LSP communication)
---@param uri string The jdt:// URI
---@return string|nil The jar: URI
function M.jdt_to_jar(uri)
  local zipfile = M.jdt_to_zipfile(uri)
  if zipfile then
    return zipfile_to_jar(zipfile)
  end
  return nil
end

return M
