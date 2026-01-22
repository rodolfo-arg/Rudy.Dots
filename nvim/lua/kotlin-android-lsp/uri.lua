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

return M
