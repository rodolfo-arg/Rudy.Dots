-- kotlin-android-lsp: Workspace generation
-- Generates workspace.json for Kotlin LSP
-- Supports: Android, Kotlin JVM, Java, and mixed projects

local M = {}

local config = require("kotlin-android-lsp.config")

---@class ProjectInfo
---@field type string "android"|"kotlin"|"java"|"mixed"
---@field root string Project root directory
---@field module string Module name
---@field compile_sdk number|nil Android compileSdk version
---@field min_sdk number|nil Android minSdk version
---@field kotlin_version string|nil Kotlin version
---@field java_version string|nil Java version
---@field has_kotlin boolean Has Kotlin sources
---@field has_java boolean Has Java sources
---@field is_multimodule boolean Is a multi-module project

---Read file contents
---@param path string
---@return string|nil
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*all")
  f:close()
  return content
end

---Parse build.gradle or build.gradle.kts to extract project info
---@param project_root string
---@param module string
---@return ProjectInfo
local function parse_build_gradle(project_root, module)
  local info = {
    type = "unknown",
    root = project_root,
    module = module,
    compile_sdk = nil,
    min_sdk = nil,
    kotlin_version = nil,
    java_version = nil,
    has_kotlin = false,
    has_java = false,
    is_multimodule = false,
  }

  -- Check if multi-module project
  local settings_gradle = read_file(project_root .. "/settings.gradle")
    or read_file(project_root .. "/settings.gradle.kts")
  if settings_gradle then
    info.is_multimodule = settings_gradle:match("include") ~= nil
  end

  -- Determine module path
  local module_path = project_root
  if info.is_multimodule and module ~= "" then
    module_path = project_root .. "/" .. module:gsub(":", "/")
  end

  -- Read module build.gradle
  local build_gradle = read_file(module_path .. "/build.gradle")
    or read_file(module_path .. "/build.gradle.kts")
    or read_file(project_root .. "/build.gradle")
    or read_file(project_root .. "/build.gradle.kts")

  if build_gradle then
    -- Detect Android
    if build_gradle:match("android%s*{") or build_gradle:match("com.android") then
      info.type = "android"

      -- Extract compileSdk
      local compile_sdk = build_gradle:match("compileSdk%s*[=]?%s*(%d+)")
        or build_gradle:match("compileSdkVersion%s*[=]?%s*(%d+)")
      if compile_sdk then
        info.compile_sdk = tonumber(compile_sdk)
      end

      -- Extract minSdk
      local min_sdk = build_gradle:match("minSdk%s*[=]?%s*(%d+)")
        or build_gradle:match("minSdkVersion%s*[=]?%s*(%d+)")
      if min_sdk then
        info.min_sdk = tonumber(min_sdk)
      end
    end

    -- Detect Kotlin
    if build_gradle:match("kotlin") or build_gradle:match("org.jetbrains.kotlin") then
      if info.type == "android" then
        info.type = "android" -- Keep as Android if both
      elseif info.type == "unknown" then
        info.type = "kotlin"
      end

      -- Extract Kotlin version from various patterns
      local kotlin_version = build_gradle:match('kotlin%("jvm"%)[^v]*version%s*[=]?%s*"([^"]+)"')
        or build_gradle:match("org.jetbrains.kotlin:kotlin[^:]*:([%d%.]+)")
        or build_gradle:match('kotlinVersion%s*[=]?%s*"([^"]+)"')
      if kotlin_version then
        info.kotlin_version = kotlin_version
      end
    end

    -- Detect Java version
    local java_version = build_gradle:match("sourceCompatibility%s*[=]?%s*['\"]?([%d%.]+)")
      or build_gradle:match("JavaVersion%.VERSION_(%d+)")
      or build_gradle:match("jvmTarget%s*[=]?%s*['\"]([^'\"]+)")
    if java_version then
      info.java_version = java_version
    end

    -- If still unknown but has java plugin
    if info.type == "unknown" and build_gradle:match("java") then
      info.type = "java"
    end
  end

  -- Check for source directories
  local src_main = module_path .. "/src/main"
  info.has_kotlin = vim.fn.isdirectory(src_main .. "/kotlin") == 1
    or vim.fn.glob(module_path .. "/**/*.kt", false, true)[1] ~= nil
  info.has_java = vim.fn.isdirectory(src_main .. "/java") == 1
    or vim.fn.glob(module_path .. "/**/*.java", false, true)[1] ~= nil

  -- Refine type based on sources
  if info.type == "unknown" then
    if info.has_kotlin and info.has_java then
      info.type = "mixed"
    elseif info.has_kotlin then
      info.type = "kotlin"
    elseif info.has_java then
      info.type = "java"
    end
  end

  return info
end

---Get the plugin's root directory
---@return string|nil
local function get_plugin_root()
  -- Find the plugin directory by looking for this file in runtime paths
  local paths = vim.api.nvim_list_runtime_paths()
  for _, path in ipairs(paths) do
    local script = path .. "/scripts/kotlin-lsp-workspace-json"
    if vim.fn.filereadable(script) == 1 then
      return path
    end
  end
  return nil
end

---Get the workspace generator script path
---@return string
local function get_script_path()
  if config.options.workspace_script then
    return config.options.workspace_script
  end

  -- First try plugin's bundled script
  local plugin_root = get_plugin_root()
  if plugin_root then
    local bundled = plugin_root .. "/scripts/kotlin-lsp-workspace-json"
    if vim.fn.filereadable(bundled) == 1 then
      return bundled
    end
  end

  -- Fallback locations
  local script_locations = {
    vim.fn.stdpath("config") .. "/../scripts/kotlin-lsp-workspace-json",
    vim.fn.expand("~/Rudy.Dots/scripts/kotlin-lsp-workspace-json"),
    vim.fn.exepath("kotlin-lsp-workspace-json"),
  }

  for _, path in ipairs(script_locations) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end

  return "kotlin-lsp-workspace-json"
end

---Check if a directory is a valid project
---@param project_root string
---@return boolean, string|nil
local function validate_project(project_root)
  local markers = {
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts",
    "pom.xml", -- Maven support
  }

  for _, marker in ipairs(markers) do
    if vim.fn.filereadable(project_root .. "/" .. marker) == 1 then
      return true, nil
    end
  end

  return false, "No build files found (Gradle/Maven) in " .. project_root
end

---Show a notification (uses fidget.nvim or snacks.nvim if available, else vim.notify)
---@param msg string
---@param level number|nil vim.log.levels
---@param opts table|nil
local function notify(msg, level, opts)
  opts = opts or {}
  opts.title = opts.title or "Kotlin Android LSP"

  -- Try snacks.nvim first (LazyVim default)
  local ok_snacks, snacks = pcall(require, "snacks")
  if ok_snacks and snacks.notify then
    snacks.notify(msg, { level = level, title = opts.title })
    return
  end

  -- Fallback to vim.notify
  vim.notify(msg, level, opts)
end

---Generate workspace.json for a project
---@param project_root string|nil Project root directory (default: cwd)
---@param module string|nil Gradle module name (default: from config)
function M.generate(project_root, module)
  project_root = vim.fn.expand(project_root or vim.fn.getcwd())
  module = module or config.options.default_module

  -- Validate project
  local valid, err = validate_project(project_root)
  if not valid then
    notify(err, vim.log.levels.ERROR)
    return
  end

  -- Parse project info
  local project_info = parse_build_gradle(project_root, module)

  -- Show project info
  local type_display = {
    android = "Android",
    kotlin = "Kotlin JVM",
    java = "Java",
    mixed = "Mixed (Kotlin + Java)",
    unknown = "Unknown",
  }

  -- Show loading notification
  local project_name = vim.fn.fnamemodify(project_root, ":t")
  notify(
    string.format("Generating workspace.json for %s (%s)...", project_name, type_display[project_info.type] or "Unknown"),
    vim.log.levels.INFO
  )

  -- Run the generator script
  local script = get_script_path()
  local cmd = string.format(
    "%s %s %s",
    vim.fn.shellescape(script),
    vim.fn.shellescape(project_root),
    vim.fn.shellescape(module)
  )

  local start_time = vim.loop.now()

  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      vim.schedule(function()
        local elapsed = vim.loop.now() - start_time
        local elapsed_str = string.format("%.1fs", elapsed / 1000)

        if exit_code == 0 then
          notify(
            string.format("Workspace generated for %s (%s)", project_name, elapsed_str),
            vim.log.levels.INFO
          )
          M.prompt_restart_lsp()
        else
          notify(
            string.format("Failed to generate workspace (exit code: %d)", exit_code),
            vim.log.levels.ERROR
          )
        end
      end)
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= "" then
            vim.schedule(function()
              notify(line, vim.log.levels.WARN)
            end)
          end
        end
      end
    end,
  })
end

---Prompt user to restart Kotlin LSP
function M.prompt_restart_lsp()
  vim.ui.select({ "Yes", "No" }, {
    prompt = "Restart Kotlin LSP to load new workspace?",
  }, function(choice)
    if choice == "Yes" then
      M.restart_kotlin_lsp()
    end
  end)
end

---Restart Kotlin LSP
function M.restart_kotlin_lsp()
  local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  for _, client in ipairs(clients) do
    vim.lsp.stop_client(client.id)
  end

  vim.defer_fn(function()
    vim.cmd("LspStart kotlin_lsp")
    vim.notify("Kotlin LSP restarted", vim.log.levels.INFO, { title = "Kotlin Android LSP" })
  end, 500)
end

---Show workspace information for current project
function M.info()
  local cwd = vim.fn.getcwd()
  local workspace_file = cwd .. "/workspace.json"
  local project_info = parse_build_gradle(cwd, config.options.default_module)

  local type_display = {
    android = "Android",
    kotlin = "Kotlin JVM",
    java = "Java",
    mixed = "Mixed (Kotlin + Java)",
    unknown = "Unknown",
  }

  local info = {
    "Kotlin Android LSP - Workspace Info",
    "====================================",
    "",
    "Project root: " .. cwd,
    "Project type: " .. (type_display[project_info.type] or "Unknown"),
    "Multi-module: " .. (project_info.is_multimodule and "Yes" or "No"),
    "",
    "Versions:",
  }

  if project_info.compile_sdk then
    table.insert(info, "  Android compileSdk: " .. project_info.compile_sdk)
  end
  if project_info.min_sdk then
    table.insert(info, "  Android minSdk: " .. project_info.min_sdk)
  end
  if project_info.kotlin_version then
    table.insert(info, "  Kotlin: " .. project_info.kotlin_version)
  end
  if project_info.java_version then
    table.insert(info, "  Java: " .. project_info.java_version)
  end

  table.insert(info, "")
  table.insert(info, "Sources:")
  table.insert(info, "  Has Kotlin: " .. (project_info.has_kotlin and "Yes" or "No"))
  table.insert(info, "  Has Java: " .. (project_info.has_java and "Yes" or "No"))

  table.insert(info, "")
  table.insert(info, "Workspace:")
  table.insert(info, "  File: " .. workspace_file)
  table.insert(info, "  Exists: " .. (vim.fn.filereadable(workspace_file) == 1 and "Yes" or "No"))

  -- Check for active LSP clients
  local kotlin_clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
  local jdtls_clients = vim.lsp.get_clients({ name = "jdtls" })

  table.insert(info, "")
  table.insert(info, "Active LSP Clients:")
  table.insert(info, "  kotlin_lsp: " .. #kotlin_clients)
  table.insert(info, "  jdtls: " .. #jdtls_clients)

  -- Check Android SDK
  local sdk_root = config.options.android.sdk_root
  table.insert(info, "")
  table.insert(info, "Android SDK: " .. (sdk_root or "Not configured"))

  if sdk_root and vim.fn.isdirectory(sdk_root) == 1 then
    local sources_dir = sdk_root .. "/sources"
    if vim.fn.isdirectory(sources_dir) == 1 then
      local sources = vim.fn.glob(sources_dir .. "/android-*", false, true)
      if #sources > 0 then
        table.insert(info, "Available sources: " .. table.concat(vim.tbl_map(function(s)
          return vim.fn.fnamemodify(s, ":t")
        end, sources), ", "))
      end
    end
  end

  -- Show in floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, info)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local width = 60
  local height = math.min(#info, 30)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = (vim.o.columns - width) / 2,
    row = (vim.o.lines - height) / 2,
    style = "minimal",
    border = "rounded",
    title = " Kotlin Android LSP ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

---Get parsed project info for current directory
---@return ProjectInfo
function M.get_project_info()
  return parse_build_gradle(vim.fn.getcwd(), config.options.default_module)
end

return M
